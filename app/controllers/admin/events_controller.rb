class Admin::EventsController < Admin::BaseController
  before_action :set_event, only: [ :show, :edit, :update, :destroy ]

  def index
    @events = Event.order(starts_at: :desc).with_attached_cover_image
  end

  def show
  end

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(event_params)
    if @event.save
      redirect_to admin_events_path, notice: "Event created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      redirect_to admin_events_path, notice: "Event updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to admin_events_path, notice: "Event deleted."
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(
      :title, :description, :event_type, :starts_at, :ends_at,
      :location, :url, :published, :cover_image, :pin_color, :pin_icon
    )
  end
end
