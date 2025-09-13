Your refactor is correct overall. Two small fixes will make it robust:

1. Compare trust domains with `.Equal(...)` (not by string).
2. Provide sane defaults for `Clock` and `RandReader` in the in-memory provider (avoid nil deref / weak entropy).

Below is a minimal patch you can apply.

---

### Patch

```diff
diff --git a/e5s/internal/adapters/outbound/inmemory/provider.go b/e5s/internal/adapters/outbound/inmemory/provider.go
index 67bc57c..f3b9e3a 100644
--- a/e5s/internal/adapters/outbound/inmemory/provider.go
+++ b/e5s/internal/adapters/outbound/inmemory/provider.go
@@ -15,6 +15,7 @@ import (
 	"crypto/x509"
 	"fmt"
 	"io"
+	"crypto/rand"
 	"math/big"
 	"net"
 	"sync"
@@ -33,6 +34,11 @@ import (
 // Interface conformance check
 var _ ports.IdentityProvider = (*Provider)(nil)
 
+// realClock is the default Clock implementation
+type realClock struct{}
+func (realClock) Now() time.Time { return time.Now() }
+
+
 // staticSource implements both x509svid.Source and x509bundle.Source interfaces
 // for the in-memory provider. It holds static (non-rotating) certificates.
 type staticSource struct {
@@ -51,7 +57,7 @@ func (s *staticSource) GetX509SVID() (*x509svid.SVID, error) {
 func (s *staticSource) GetX509BundleForTrustDomain(td spiffeid.TrustDomain) (*x509bundle.Bundle, error) {
 	s.mu.RLock()
 	defer s.mu.RUnlock()
-	if s.bundle == nil || s.bundle.TrustDomain().String() != td.String() {
+	if s.bundle == nil || !s.bundle.TrustDomain().Equal(td) {
 		return nil, fmt.Errorf("bundle not initialized for %s", td)
 	}
 	return s.bundle, nil
@@ -145,6 +151,12 @@ func NewProvider(opts Options) (*Provider, error) {
 	if err != nil {
 		return nil, fmt.Errorf("%w: failed to create root certificate: %v", errx.ErrCertificateGeneration, err)
 	}
+	// Defaults for optional dependencies
+	if opts.Clock == nil {
+		opts.Clock = realClock{}
+	}
+	if opts.RandReader == nil {
+		opts.RandReader = rand.Reader
+	}
 	// Create bundle from root CA
 	bundle := bundleFromRoot(td, rootCert)
 
```

*(No other files need changes for these two issues.)*

---

### Why these changes

* **`TrustDomain.Equal`** avoids subtle mismatches (string forms can differ in case/format, `.Equal` is the intended API).
* **Default `Clock`/`RandReader`** ensures `opts.Clock.Now()` won’t panic and keys/certs use a secure RNG if the caller didn’t provide one.

---

### Quick sanity checks

* `go build ./...`
* `go test ./...`
* With SPIRE provider: connect twice a few minutes apart (short SVID TTL) and confirm new handshakes present a new leaf serial (rotation happens automatically via `workloadapi.X509Source`).
* With in-memory provider: a single handshake should succeed; no rotation expected.

### Optional (nice to have)

* Replace `tlsconfig.AuthorizeAny()` with a stricter authorizer once you know your client IDs (`AuthorizeID` / `AuthorizeMemberOf`).
* In `Close()`, you can nil out `p.src.svid`/`p.src.bundle` to help GC in long-lived tests (not required).

**Key takeaway:** you’ve fully removed custom rotation; go-spiffe now handles it. The patch above cleans up two edge cases.
