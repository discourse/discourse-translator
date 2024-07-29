# frozen_string_literal: true

class ProblemCheck::MicrosoftAzureKey < ProblemCheck
  self.priority = "high"

  def call
    return no_problem unless SiteSetting.translator_enabled
    return no_problem if SiteSetting.translator != "Microsoft"
    return problem if SiteSetting.translator_azure_subscription_key.blank?

    no_problem
  end
end
