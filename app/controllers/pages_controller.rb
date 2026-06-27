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
    # View renders hardcoded biography prose + Repertoire PORO; no instance vars needed.
  end

  def projects
    @trees = Tree.published.order(created_at: :desc)
    @new_tree = Tree.new
    @stats = {
      trees: Tree.published.sum(:tree_count),
      cities: Tree.published.where.not(address: nil).distinct.count(:address),
      countries: 9,
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
