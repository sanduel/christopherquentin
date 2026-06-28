class Admin::UsersController < Admin::BaseController
  def index
    @users = User.order(:name)
  end

  def update
    user = User.find(params[:id])

    if user == current_user
      redirect_to admin_users_path, alert: "You can't change your own role."
      return
    end

    if User.roles.key?(params[:role])
      user.update(role: params[:role])
      redirect_to admin_users_path, notice: "#{user.name} is now a#{params[:role] == "admin" ? "n" : ""} #{params[:role]}."
    else
      redirect_to admin_users_path, alert: "Invalid role."
    end
  end
end
