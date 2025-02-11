import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import LanguageSwitcher from "../components/language-switcher";
import ToggleTranslationButton from "../components/post-menu/toggle-translation-button";
import ShowOriginalContent from "../components/show-original-content";
import TranslatedPost from "../components/translated-post";

function initializeTranslation(api) {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.translator_enabled) {
    return;
  }

  const currentUser = api.getCurrentUser();

  if (!currentUser && siteSettings.experimental_anon_language_switcher) {
    api.headerIcons.add(
      "discourse-translator_language-switcher",
      LanguageSwitcher,
      { before: ["search"] }
    );
  }

  if (
    siteSettings.experimental_topic_translation &&
    (currentUser || siteSettings.experimental_anon_language_switcher)
  ) {
    api.renderInOutlet("topic-navigation", ShowOriginalContent);
    api.decorateCookedElement((cookedElement, helper) => {
      if (helper) {
        const translatedCooked = helper.getModel().get("translated_cooked");
        if (translatedCooked) {
          cookedElement.innerHTML = translatedCooked;
        } else {
          // this experimental feature does not yet support
          // translating individual untranslated posts
        }
      }
    });

    api.registerModelTransformer("topic", (topics) => {
      topics.forEach((topic) => {
        if (topic.translated_title) {
          topic.set("fancy_title", topic.translated_title);
        }
      });
    });
  }

  if (!siteSettings.experimental_topic_translation) {
    customizePostMenu(api);
  }
}

function customizePostMenu(api, container) {
  const transformerRegistered = api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { firstButtonKey } }) => {
      dag.add("translate", ToggleTranslationButton, { before: firstButtonKey });
    }
  );

  if (transformerRegistered) {
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

  const silencedKey =
    transformerRegistered && "discourse.post-menu-widget-overrides";

  withSilencedDeprecations(silencedKey, () =>
    customizeWidgetPostMenu(api, container)
  );
}

function customizeWidgetPostMenu(api) {
  api.includePostAttributes(
    "can_translate",
    "translated_text",
    "detected_lang",
    "translated_title"
  );

  const siteSettings = api.container.lookup("service:site-settings");
  api.decorateWidget("post-menu:before", (dec) => {
    if (!dec.state.isTranslated) {
      return;
    }

    if (dec.state.isTranslating) {
      return dec.h("div.spinner.small");
    }

    const language = dec.attrs.detected_lang;
    const translator = siteSettings.translator;

    let titleElements = [];

    if (dec.attrs.translated_title) {
      titleElements = [
        dec.h("div.topic-attribution", dec.attrs.translated_title),
      ];
    }

    return dec.h("div.post-translation", [
      dec.h("hr"),
      ...titleElements,
      dec.h(
        "div.post-attribution",
        i18n("translator.translated_from", { language, translator })
      ),
      dec.cooked(dec.attrs.translated_text),
    ]);
  });

  api.attachWidgetAction("post-menu", "translate", function () {
    const state = this.state;
    state.isTranslated = true;
    state.isTranslating = true;
    this.scheduleRerender();

    const post = this.findAncestorModel();

    if (post) {
      return ajax("/translator/translate", {
        type: "POST",
        data: { post_id: post.get("id") },
      })
        .then(function (res) {
          post.setProperties({
            translated_text: res.translation,
            detected_lang: res.detected_lang,
            translated_title: res.title_translation,
          });
        })
        .catch((error) => {
          popupAjaxError(error);
          state.isTranslating = false;
          state.isTranslated = false;
        })
        .finally(() => (state.isTranslating = false));
    }
  });

  api.attachWidgetAction("post-menu", "hideTranslation", function () {
    this.state.isTranslated = false;
    const post = this.findAncestorModel();
    if (post) {
      post.set("translated_text", "");
    }
  });

  api.addPostMenuButton("translate", (attrs, state) => {
    if (!attrs.can_translate) {
      return;
    }

    const [action, title] = !state.isTranslated
      ? ["translate", "translator.view_translation"]
      : ["hideTranslation", "translator.hide_translation"];

    return {
      action,
      title,
      icon: "globe",
      position: "first",
      className: state.isTranslated ? "translated" : null,
    };
  });
}

export default {
  name: "extend-for-translate-button",
  initialize() {
    withPluginApi("1.39.2", (api) => initializeTranslation(api));
  },
};
