class PagesController < ApplicationController
  def home
    @timeline_preview_memories = Memory.published.order(date: :desc, created_at: :desc).limit(3)
    @memories_count = Memory.published.count
    @upcoming_events = Event.published.upcoming.limit(3)
    @gallery_photos = GalleryPhoto.all.limit(12)
    @recent_tributes = Tribute.published.order(created_at: :desc).limit(3)
    @tributes_count = Tribute.published.count
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
    @items_by_year = PressItem.grouped_by_year
    @total = PressItem.all.count
    @years = PressItem.years
  end

  def style_guide
    # View exercises all design tokens + shared partials.
  end
end
