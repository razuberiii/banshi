class SessionsController < ApplicationController
  def new; end
  def create
    user=User.find_by(email:params[:email].to_s.strip.downcase)
    if user&.authenticate(params[:password])
      reset_session;session[:user_id]=user.id
      redirect_to root_path,notice:'入馆成功，慢慢逛。'
    else flash.now[:alert]='邮箱或密码不正确。';render :new,status: :unprocessable_entity
    end
  end
  def demo
    raise ActiveRecord::RecordNotFound unless AppConfig.demo.enabled
    user=User.find_by!(email:AppConfig.demo.email)
    reset_session;session[:user_id]=user.id
    redirect_to demo_path,notice:'已领取演示馆务证。'
  end
  def destroy
    reset_session
    redirect_to root_path,notice:'已经离馆，欢迎下次考古。'
  end
end
