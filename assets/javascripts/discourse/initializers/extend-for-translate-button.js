import { withPluginApi } from "discourse/lib/plugin-api";
import ToggleTranslationButton from "../components/post-menu/toggle-translation-button";
import TranslatedPost from "../components/translated-post";

function initializeTranslation(api) {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.translator_enabled) {
    return;
  }

  customizePostMenu(api);
}

function customizePostMenu(api) {
  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { firstButtonKey } }) => {
      dag.add("translate", ToggleTranslationButton, { before: firstButtonKey });
    }
  );

  // the plugin outlet is not updated when the post instance is modified unless we register the new properties as
  // tracked
  api.addTrackedPostProperties(
    "detectedLang",
    "isTranslating",
    "isTranslated",
    "translatedText",
    "translatedTitle"
  );

  api.renderBeforeWrapperOutlet("post-menu", TranslatedPost);
}

export default {
  name: "extend-for-translate-button",
  initialize() {
    withPluginApi("1.39.2", (api) => initializeTranslation(api));
  },
};
