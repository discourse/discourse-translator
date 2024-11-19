import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import i18n from "discourse-common/helpers/i18n";

export default class TranslatedPost extends Component {
  static shouldRender(args) {
    return args.post.isTranslated || args.post.isTranslating;
  }

  @service siteSettings;

  get loading() {
    return this.post.isTranslating;
  }

  get isTranslated() {
    return this.post.isTranslated;
  }

  get post() {
    return this.args.outletArgs.post;
  }

  get translatedText() {
    return this.post.translatedText;
  }

  get translatedTitle() {
    return this.post.translatedTitle;
  }

  <template>
    <div class="post-translation">
      <ConditionalLoadingSpinner
        class="post-translation"
        @condition={{this.loading}}
        @size="small"
      >
        <hr />
        {{#if this.translatedTitle}}
          <div class="topic-attribution">
            {{this.translatedTitle}}
          </div>
        {{/if}}
        <div class="post-attribution">
          {{i18n
            "translator.translated_from"
            language=this.post.detectedLang
            translator=this.siteSettings.translator
          }}
        </div>
        <div class="cooked">
          {{htmlSafe this.post.translatedText}}
        </div>
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
