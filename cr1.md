Your refactor is solid and aligns with “let go-spiffe do rotation.” A few small fixes will prevent build/runtime surprises.

# What’s correct

* Removed custom rotation (`rotation.go`, `tlsstore.go`, `WatchRotation`, `ErrRotationFailed`).
* `ServerService` now uses `tlsconfig.MTLSServerConfig(...)` with sources.
* SPIRE provider exposes `SVIDSource`/`BundleSource`.
* Health check verifies SVID and that sources are non-nil.
* In-memory provider now returns sources (static, non-rotating).

# Must-fix items

1. **`pem.ToX509SVID` uses helpers that likely don’t exist**
   You call `DecodeCertChain` and `DecodePrivateKey`. If those aren’t already exported in your `pem` package, compilation will fail. Either add them or inline the parsing.

2. **TrustDomain equality check**
   Prefer `spiffeid.TrustDomain.Equal(td)` to `!=` for clarity and future-proofing.

3. **Default clock safety**
   `opts.Clock.Now()` assumes `Clock` is non-nil. If `Options.Clock` can be nil, set a default.

4. **Enforce non-nil sources before TLS**
   You already guard this in `ServerService.Prepare`—good. Keep it.

# Minimal diffs to apply

## A) Inline parse in `pem.ToX509SVID` (no external helpers)

```diff
diff --git a/e5s/internal/adapters/outbound/pem/pem.go b/e5s/internal/adapters/outbound/pem/pem.go
index 78fdfec..f0f0f0a 100644
--- a/e5s/internal/adapters/outbound/pem/pem.go
+++ b/e5s/internal/adapters/outbound/pem/pem.go
@@ -1,12 +1,15 @@
 package pem
 
 import (
+	"crypto"
+	"crypto/ecdsa"
+	"crypto/rsa"
 	"crypto/x509"
 	"encoding/pem"
 	"fmt"
 
 	"github.com/spiffe/go-spiffe/v2/spiffeid"
 	"github.com/spiffe/go-spiffe/v2/svid/x509svid"
 	errx "github.com/sufield/e5s/internal/errors"
 )
@@ -255,35 +258,64 @@ func parsePrivateKeyBlock(block *pem.Block) (crypto.PrivateKey, error) {
 	}
 }
 
 // ToX509SVID converts PEM-encoded certificate and key to an x509svid.SVID
 // This is used by the in-memory provider to create static sources
 func ToX509SVID(certPEM, keyPEM []byte, id spiffeid.ID) (*x509svid.SVID, error) {
-	// Parse certificate chain
-	certs, err := DecodeCertChain(certPEM)
-	if err != nil {
-		return nil, fmt.Errorf("failed to decode certificate chain: %w", err)
-	}
-	if len(certs) == 0 {
-		return nil, fmt.Errorf("certificate chain is empty")
-	}
-
-	// Parse private key
-	key, err := DecodePrivateKey(keyPEM)
-	if err != nil {
-		return nil, fmt.Errorf("failed to decode private key: %w", err)
-	}
-
-	// Ensure key implements crypto.Signer
-	signer, ok := key.(crypto.Signer)
-	if !ok {
-		return nil, fmt.Errorf("private key does not implement crypto.Signer")
-	}
-
-	return &x509svid.SVID{
-		ID:           id,
-		Certificates: certs,
-		PrivateKey:   signer,
-	}, nil
+	// 1) Parse certificate chain (leaf first)
+	var certs []*x509.Certificate
+	rest := certPEM
+	for {
+		var blk *pem.Block
+		blk, rest = pem.Decode(rest)
+		if blk == nil {
+			break
+		}
+		if blk.Type != "CERTIFICATE" {
+			continue
+		}
+		c, err := x509.ParseCertificate(blk.Bytes)
+		if err != nil {
+			return nil, fmt.Errorf("parse certificate: %w", err)
+		}
+		certs = append(certs, c)
+	}
+	if len(certs) == 0 {
+		return nil, fmt.Errorf("certificate chain is empty")
+	}
+
+	// 2) Parse private key
+	kb, _ := pem.Decode(keyPEM)
+	if kb == nil {
+		return nil, fmt.Errorf("%w: private key PEM empty", errx.ErrInvalidPEM)
+	}
+	var key any
+	var err error
+	if key, err = x509.ParsePKCS8PrivateKey(kb.Bytes); err != nil {
+		if key, err = x509.ParsePKCS1PrivateKey(kb.Bytes); err != nil {
+			if key, err = x509.ParseECPrivateKey(kb.Bytes); err != nil {
+				return nil, fmt.Errorf("%w: parse private key: %w", errx.ErrParseKeyFailed, err)
+			}
+		}
+	}
+	signer, ok := key.(crypto.Signer)
+	if !ok {
+		// Should not happen with rsa.PrivateKey or ecdsa.PrivateKey
+		if _, ok := key.(*rsa.PrivateKey); !ok {
+			if _, ok := key.(*ecdsa.PrivateKey); !ok {
+				return nil, fmt.Errorf("private key does not implement crypto.Signer")
+			}
+		}
+	}
+
+	// 3) Build SVID
+	return &x509svid.SVID{
+		ID:           id,
+		Certificates: certs, // leaf first
+		PrivateKey:   signer,
+	}, nil
 }
```

## B) TrustDomain equality in static source

```diff
diff --git a/e5s/internal/adapters/outbound/inmemory/provider.go b/e5s/internal/adapters/outbound/inmemory/provider.go
@@
-func (s *staticSource) GetX509BundleForTrustDomain(td spiffeid.TrustDomain) (*x509bundle.Bundle, error) {
+func (s *staticSource) GetX509BundleForTrustDomain(td spiffeid.TrustDomain) (*x509bundle.Bundle, error) {
 	s.mu.RLock()
 	defer s.mu.RUnlock()
-	if s.bundle == nil || s.bundle.TrustDomain() != td {
+	if s.bundle == nil || !s.bundle.TrustDomain().Equal(td) {
 		return nil, fmt.Errorf("bundle not initialized for %s", td)
 	}
 	return s.bundle, nil
 }
```

## C) Default clock (defensive)

```diff
diff --git a/e5s/internal/adapters/outbound/inmemory/provider.go b/e5s/internal/adapters/outbound/inmemory/provider.go
@@
 func NewProvider(opts Options) (*Provider, error) {
+	if opts.Clock == nil {
+		opts.Clock = realClock{} // implement realClock { func Now() time.Time { return time.Now() } }
+	}
```

If you already have a default elsewhere, you can skip this.

# Nice-to-have

* In `ServerService`: replace `AuthorizeAny()` with a stricter authorizer when you wire policy:

  ```go
  tlsconfig.MTLSServerConfig(svidSrc, bundleSrc,
      tlsconfig.AuthorizeID(spiffeid.RequireFromString("spiffe://example.org/client")),
  )
  ```
* Keep ports layer tech-agnostic by introducing tiny interfaces if you want strict hexagonal boundaries. What you have now is fine if you accept go-spiffe as a port-level dependency.

# Sanity checks

* `go build ./...` (will catch the missing helpers).
* `go test ./...`.
* SPIRE e2e: set short SVID TTL, connect twice minutes apart—new handshakes should show a new leaf serial (no code changes needed; rotation is automatic).

* You’ve correctly removed custom rotation.
* Ensure `pem.ToX509SVID` compiles (inline parsing fix above).
* Prefer `TrustDomain.Equal`.
* Guard defaults and keep the non-nil source checks.
