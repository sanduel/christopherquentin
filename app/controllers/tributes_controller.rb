class TributesController < ApplicationController
  before_action :require_admin!, only: [ :edit, :update ]

  def index
    scope = Tribute.published.with_attached_photo.order(created_at: :desc)
    requested = params[:category].presence
    @active_category = (requested if Tribute.categories.key?(requested.to_s))
    @tributes = @active_category ? scope.where(category: @active_category) : scope
    @categories = Tribute.categories.keys
    @total_count = Tribute.published.count
  end

  def show
    scope = current_user&.admin? ? Tribute.all : Tribute.published
    @tribute = scope.find(params[:id])
  end

  def new
    @tribute = Tribute.new(category: :friends)
  end

  def create
    @tribute = Tribute.new(tribute_params)
    @tribute.status = :pending

    if @tribute.save
      redirect_to tributes_path, notice: "Thank you for your tribute. It will appear after review."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Admin-only (see require_admin!). Admins may edit a tribute of any status.
  def edit
    @tribute = Tribute.find(params[:id])
  end

  def update
    @tribute = Tribute.find(params[:id])

    if @tribute.update(admin_tribute_params)
      redirect_to tribute_path(@tribute), notice: "Tribute updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def tribute_params
    params.require(:tribute).permit(:name, :relationship, :content, :category, :photo, :video_url)
  end

  # Full field set, including moderation fields. Only reachable from the
  # admin-guarded edit/update actions, so public create can't use these.
  def admin_tribute_params
    params.require(:tribute).permit(:name, :relationship, :content, :category, :photo, :video_url, :status, :user_id)
  end

  def require_admin!
    authenticate_user!
    redirect_to root_path, alert: "Not authorized." unless current_user&.admin?
  end
end
