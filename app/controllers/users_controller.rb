class UsersController < ApplicationController
  def new = @user=User.new
  def create
    @user=User.new(params.require(:user).permit(:email,:display_name,:password,:password_confirmation))
    if @user.save
      reset_session;session[:user_id]=@user.id
      redirect_to profile_path(@user),notice:'你的入馆证已办好。'
    else render :new,status: :unprocessable_entity
    end
  end
  def show
    @user=User.find_by!(public_id:params[:public_id])
    @own=current_user==@user
    @favorites=@own ? ShitEntry.publicly_visible.where(id:@user.favorites.select(:shit_entry_id)).recent : []
    @groups=@own ? @user.managed_groups : []
  end
end
