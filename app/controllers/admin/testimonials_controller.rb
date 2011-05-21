class Admin::TestimonialsController < AdminController
  before_filter :authenticate

  def index
    @testimonials = Testimonial.all
  end

  def show
    @testimonial = Testimonial.find(params[:id])
  end

  def new
    @testimonial = Testimonial.new
  end

  def edit
    @testimonial = Testimonial.find(params[:id])
  end

  def create
    @testimonial = Testimonial.new(params[:testimonial])

    if @testimonial.save
      flash[:notice] = 'Testimonial was successfully created.'
      redirect_to admin_testimonials_url
    else
      render :action => "new"
    end
  end

  def update
    @testimonial = Testimonial.find(params[:id])

    if @testimonial.update_attributes(params[:testimonial])
      flash[:notice] = 'Testimonial was successfully updated.'
      redirect_to admin_testimonials_url
    else
      format.html { render :action => "edit" }
    end
  end

  def destroy
    @testimonial = Testimonial.find(params[:id])
    @testimonial.destroy

    redirect_to admin_testimonials_url
  end
end
