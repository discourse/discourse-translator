import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class TranslatorService extends Service {
  @service siteSettings;
  @service appEvents;
  @service documentTitle;

  async translatePost(post) {
    const response = await ajax("/translator/translate", {
      type: "POST",
      data: { post_id: post.id },
    });

    post.detectedLang = response.detected_lang;
    post.translatedText = response.translation;
    post.translatedTitle = response.title_translation;
  }

  clearPostTranslation(post) {
    post.detectedLang = null;
    post.translatedText = null;
    post.translatedTitle = null;
  }
}
