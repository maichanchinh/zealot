# frozen_string_literal: true

# 默认开启 Sentry，如果不想使用设置 ZEALOT_SENTRY_DISABLE=1
if Rails.env.production? && ActiveModel::Type::Boolean.new.cast(ENV['ZEALOT_SENTRY_DISABLE'] || false)
  Rails.configuration.to_prepare do
    Sentry.init do |config|
      config.dsn = ENV['ZEALOT_SENTRY_DNS'] || 'https://133aefa9f52448a1a7900ba9d02f93e1@o333914.ingest.sentry.io/1878137'

      config.include_local_variables = true
      config.rails.report_rescued_exceptions = true
      config.breadcrumbs_logger = %i[active_support_logger sentry_logger http_logger]

      config.send_default_pii = true
      config.environment = Rails.env
      config.enabled_environments = %w[production development]

      config.excluded_exceptions += [
        'ActionController::RoutingError',
        'ActiveRecord::RecordNotFound',
        'ActiveRecord::RecordInvalid',
        'ActiveRecord::NoDatabaseError',
        'ActiveRecord::PendingMigrationError',
        'PG::ConnectionBad',
        'AppInfo::UnkownFileTypeError',
        'Interrupt',
        'SystemExit',
      ]

      config.traces_sampler = lambda do |sampling_context|
        transaction_context = sampling_context[:transaction_context]
        op = transaction_context[:op]
        case op
        when /sidekiq/
          0.01
        else
          0.8
        end
      end

      if vcs_ref = Setting.vcs_ref.presence
        release = [Setting.version, vcs_ref]
        if docker_tag = ENV['DOCKER_TAG'].presence
          release << ENV['DOCKER_TAG']
        end
        config.release = release.join('-')
      end
    end
  end
end
