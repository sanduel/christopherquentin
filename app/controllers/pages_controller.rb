class PagesController < ApplicationController
  def home
    @timeline_preview_memories = Memory.published.order(date: :desc, created_at: :desc).limit(3)
    @memories_count = Memory.published.count
    @upcoming_events = Event.published.upcoming.limit(3)
    featured = GalleryPhoto.published.featured.with_attached_photo.limit(11).to_a
    @gallery_photos = featured.presence ||
                      GalleryPhoto.published.with_attached_photo.newest_first.limit(11).to_a
    @recent_tributes = Tribute.published.order(created_at: :desc).limit(3)
    @tributes_count = Tribute.published.count
  end

  def chris
    # Biography prose + Repertoire PORO are hardcoded in the view; the portrait
    # grid is filled from gallery photos tagged as portraits (first 3 by sort order).
    @portraits = GalleryPhoto.published.portraits.with_attached_photo.limit(3).to_a
  end

  def projects
    @trees = Tree.published.order(created_at: :desc)
    @new_tree = Tree.new
    @stats = {
      trees: Tree.published.sum(:tree_count),
      cities: Tree.published.where.not(address: nil).distinct.count(:address),
      countries: 9
    }
  end

  def zero_waste
  end

  def news
    @items_by_year = PressItem.grouped_by_year
    @total = PressItem.all.count
    @years = PressItem.years
  end
end
