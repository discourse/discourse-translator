# frozen_string_literal: true

module DiscourseTranslator
  module ApplicationControllerExtension
    # def with_resolved_locale(check_current_user: true)
    #   if client_locale.present?
    #     I18n.ensure_all_loaded!
    #     I18n.with_locale(client_locale) { yield }
    #   else
    #     super
    #   end
    # end

    def client_locale
      params[:lang] || cookies[:locale]
    end
  end
end
