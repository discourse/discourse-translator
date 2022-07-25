import { htmlSafe } from "@ember/template";
import { helperContext, registerUnbound } from "discourse-common/lib/helpers";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "I18n";

registerUnbound("translated-title-icon", (topic) => {
  const siteSettings = helperContext().siteSettings;
  const icon = iconHTML("globe");
  const title = I18n.t("translator.translated_from_with_original", {
    language: topic.title_language,
    translator: siteSettings.translator,
    original: topic.original_title,
  });

  return htmlSafe(
    `<span class='translated-title-icon' title='${title}'>${icon}</span>`
  );
});
