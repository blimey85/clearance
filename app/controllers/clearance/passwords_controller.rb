require 'active_support/deprecation'

class Clearance::PasswordsController < Clearance::BaseController
  before_action :ensure_existing_user, only: [:edit, :update]
  skip_before_action :require_login, only: [:create, :edit, :new, :update], raise: false

  def new
    render template: "passwords/new"
  end

  def create
    if user = find_user_for_create
      deliver_email(user)
    end

    render template: "passwords/create"
  end

  def edit
    @user = find_user_for_edit

    render template: "passwords/edit"
  end

  def update
    @user = find_user_for_update

    if @user.update_password(password_reset_params)
      sign_in(@user)
      redirect_to(url_after_update)
    else
      flash_failure_after_update
      render template: "passwords/edit"
    end
  end

  private

  def deliver_email(user)
    ::ClearanceMailer.change_password(user).deliver_later
  end

  def password_reset_params
    params[:password_reset][:password]
  end

  def find_user_for_create
    Clearance.configuration.user_model.
      find_by_normalized_email params[:password][:email]
  end

  def find_user_by_password_reset_token(token)
    verifier = Clearance.configuration.message_verifier
    user_model = Clearance.configuration.user_model

    begin
      user_id, encrypted_password, expiration = verifier.verify(token)
    rescue
      expiration = 1.day.ago
    end

    if expiration.future?
      user_model.find_by(id: user_id, encrypted_password: encrypted_password)
    end
  end

  def find_user_for_edit
    find_user_by_password_reset_token(params[:token])
  end

  def find_user_for_update
    find_user_by_password_reset_token(params[:token])
  end

  def ensure_existing_user
    unless find_user_by_password_reset_token(params[:token])
      flash_failure_when_invalid
      render template: "passwords/new"
    end
  end

  def flash_failure_when_invalid
    flash.now[:alert] = translate("flashes.failure_when_password_reset_invalid")
  end

  def flash_failure_after_update
    flash.now[:alert] = translate(:blank_password,
      scope: [:clearance, :controllers, :passwords],
      default: t("flashes.failure_after_update"))
  end

  def url_after_update
    Clearance.configuration.redirect_url
  end
end
