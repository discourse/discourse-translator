# frozen_string_literal: true

RSpec.describe "Translation settings", type: :system do
  fab!(:admin)

  before do
    sign_in(admin)
    SiteSetting.translator_enabled = true
  end

  it "warns when automatic_translation_target_languages is being set but backfill limit is 0" do
    visit(
      "/admin/plugins/discourse-translator/settings?filter=automatic%20translation%20target%20languages",
    )

    setting =
      PageObjects::Components::SelectKit.new(
        "[data-setting='automatic_translation_target_languages'] .select-kit",
      )
    setting.expand
    setting.select_row_by_value("ja")

    page.find(".setting-controls button.ok").click()

    expect(page).to have_content(I18n.t("site_settings.errors.needs_nonzero_backfill"))
  end
end
