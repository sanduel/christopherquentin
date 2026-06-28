class Admin::DashboardController < Admin::BaseController
  def index
    @pending_tributes = Tribute.pending.count
    @pending_memories = Memory.pending.count
    @pending_trees = Tree.pending.count
    @pending_recipes = Recipe.pending.count
    @pending_photos = GalleryPhoto.pending.count
    @total_subscribers = NewsletterSubscriber.count
    @upcoming_events_count = Event.published.upcoming.count
    @pending_bee_hives = BeeHive.pending.count
    @milestones_count = Milestone.count
  end
end
