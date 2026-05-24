class PagesController < ApplicationController
  def home
    @recent_tributes = Tribute.published.order(created_at: :desc).limit(3)
    @gallery_photos = GalleryPhoto.all.limit(12)
    @upcoming_events = Event.published.upcoming.with_attached_cover_image.limit(3)
  end

  def chris
    @gallery_photos = GalleryPhoto.all.limit(20)
    @memories = Memory.published.order(date: :desc).limit(10)
    @tributes = Tribute.published.order(created_at: :desc)
  end

  def projects
  end

  def funds
  end

  def zero_waste
  end

  def news
  end
end
