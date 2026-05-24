class EventsController < ApplicationController
  def index
    scope = Event.published.with_attached_cover_image
    @upcoming_events = scope.upcoming
    @past_events = scope.past
  end

  def show
    @event = Event.published.with_attached_cover_image.find(params[:id])
  end
end
