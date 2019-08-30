require 'app-info'

class Api::V2::Apps::UploadController < Api::BaseController
  before_action :validate_user_key
  before_action :set_channel

  # Upload an App
  #
  # @param key           [String] required user key
  # @param app_key       [String] required app key
  # @param file          [String] required app file
  # @param name          [String] optional app name
  # @param release_type  [String] optional release type(debug, beta, adhoc, release, enterprise etc)
  # @param source        [String] optional upload source(api, cli, jenkins, gitlab-ci etc)
  # @param changelog     [String] optional changelog
  # @param branch        [String] optional git branch
  # @param git_commit    [String] optional git commit
  # @param ci_url        [String] optional ci url
  # @return              [String] json formatted app info
  def create
    create_or_update_release

    render json: @release,
           serializer: Api::UploadAppSerializer,
           status: :created
  end

  private

  def create_or_update_release
    ActiveRecord::Base.transaction do
      if new_record?
        create_new_build
      else
        update_new_build
      end
    end
  end

  # 创建 App 并创建新版本
  def create_new_build
    create_release with_channel and_scheme and_app
  end

  # 使用现有 App 创建新版本
  def update_new_build
    message = "bundle id `#{app_info.bundle_id}` not matched with `#{@channel.bundle_id}` in channel #{@channel.id}"
    raise TypeError, message unless @channel.bundle_id_matched? app_info.bundle_id

    create_release @channel
  end

  def new_record?
    @channel.blank?
  end

  def set_channel
    @channel = Channel.find_by(key: params[:app_key])
  end

  # def release_new_record?
  #   release_find_by_params =
  #     if params[:last_commit].blank?
  #       params.permit(:release_version, :build_version)
  #     else
  #       params.permit(:release_version, :build_version, :last_commit)
  #     end

  #   @release = @app.releases.find_or_initialize_by(release_find_by_params)
  #   @new_record = @release.new_record?
  # end

  # def perform_app_web_hook_job
  #   web_hooks = WebHook.where(upload_events: 1, app: @app)
  #   return if web_hooks.empty?

  #   web_hooks.each do |web_hook|
  #     AppWebHookJob.perform_later 'upload_events', web_hook
  #   end
  # end

  # def release_params
  #   attributes = params.permit(
  #     :identifier, :release_version, :build_version,
  #     :changelog, :channel, :branch, :last_commit, :ci_url,
  #     :file, :icon, :extra, :devices, :release_type
  #   )

  #   attributes[:channel] = 'jenkins' if attributes[:ci_url].present?
  #   attributes[:devices] = param_devices
  #   attributes[:extra] = JSON.dump(param_extra)

  #   attributes
  # end

  # def param_devices
  #   @devices = nil
  #   @devices = if params[:devices] && params[:devices].present?
  #                JSON.dump(params[:devices])
  #              elsif (extra = JSON.dump(param_extra)) && extra['devices'].present?
  #                extra['devices']
  #              else
  #                nil
  #              end
  # rescue
  #   @device = nil
  # end

  # def param_extra
  #   return @extra if @extra

  #   extra = params.clone.to_unsafe_h
  #   extra.delete(:file)
  #   extra.delete(:icon) if extra.key?(:icon)

  #   @param_extra ||= extra
  # end

  def app_info
    @app_info ||= AppInfo.parse(params[:file].path)
  end

  ###########################
  # Create a new app
  ###########################
  def create_release(channel)
    @release = channel.releases.create! params.permit(:file) do |release|
      release.bundle_id = app_info.bundle_id
      release.release_version = app_info.release_version
      release.build_version = app_info.build_version
      release.release_type = app_info.release_type if app_info.os == AppInfo::Parser::Platform::IOS
      release.icon = File.open(app_info.icons.last[:file])
    end
  end

  def with_channel(scheme)
    scheme.channels.create! params.permit(:slug, :password, :git_url, :source) do |channel|
      channel.name = app_info.os
      channel.device_type = app_info.os
    end
  end

  def and_scheme(app)
    name = parse_scheme_name || '测试版'
    app.schemes.create! name: name
  end

  def and_app
    permitted = params.permit(:name)
    permitted[:name] = app_info.name unless permitted.key?(:name)

    App.create! permitted do |app|
      app.user = @user
    end
  end

  def parse_scheme_name
    return unless app_info.os == AppInfo::Parser::Platform::IOS

    case app_info.release_type
    when AppInfo::Parser::IPA::ExportType::DEBUG
      '开发版'
    when AppInfo::Parser::IPA::ExportType::ADHOC
      '测试版'
    when AppInfo::Parser::IPA::ExportType::INHOUSE
      '企业版'
    when AppInfo::Parser::IPA::ExportType::RELEASE
      '线上版'
    end
  end
end
