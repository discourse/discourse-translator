import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";

function translatePost(post) {
  return ajax("/translator/translate", {
    type: "POST",
    data: { post_id: post.get("id") },
  }).then(function (res) {
    post.setProperties({
      translated_text: res.translation,
      detected_lang: res.detected_lang,
    });
  });
}

function initializeTranslation(api) {
  const siteSettings = api.container.lookup("site-settings:main");
  const currentUser = api.getCurrentUser();

  if (!currentUser) {
    return;
  }
  if (!siteSettings.translator_enabled) {
    return;
  }

  api.includePostAttributes(
    "can_translate",
    "translated_text",
    "detected_lang"
  );

  api.decorateWidget("post-menu:before", (dec) => {
    if (!dec.state.isTranslated) {
      return;
    }

    if (dec.state.isTranslating) {
      return dec.h("div.spinner.small");
    }

    const language = dec.attrs.detected_lang;
    const translator = siteSettings.translator;

    return dec.h("div.post-translation", [
      dec.h("hr"),
      dec.h(
        "div.post-attribution",
        I18n.t("translator.translated_from", { language, translator })
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
      return translatePost(post)
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
    withPluginApi("0.1", (api) => initializeTranslation(api));
  },
};
