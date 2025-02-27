import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class ToggleTranslationButton extends Component {
  static shouldRender(args) {
    return args.post.can_translate;
  }

  @service modal;
  @service translator;

  get isTranslating() {
    return this.args.post.isTranslating;
  }

  get isTranslated() {
    return this.args.post.isTranslated;
  }

  get showButton() {
    return this.args.post.can_translate;
  }

  get title() {
    if (this.isTranslating) {
      return "translator.translating";
    }

    return this.isTranslated
      ? "translator.hide_translation"
      : "translator.view_translation";
  }

  @action
  hideTranslation() {
    this.args.post.isTranslated = false;
    this.args.post.isTranslating = false;
    this.translator.clearPostTranslation(this.args.post);
  }

  @action
  toggleTranslation() {
    return this.args.post.isTranslated
      ? this.hideTranslation()
      : this.translate();
  }

  @action
  async translate() {
    const post = this.args.post;
    post.isTranslating = true;

    try {
      await this.translator.translatePost(post);
      post.isTranslated = true;
    } catch (error) {
      this.translator.clearPostTranslation(this.args.post);
      post.isTranslated = false;
      popupAjaxError(error);
    } finally {
      post.isTranslating = false;
    }
  }

  <template>
    {{#if this.showButton}}
      <DButton
        class={{concatClass
          "post-action-menu__translate"
          (if this.isTranslated "translated")
        }}
        ...attributes
        @action={{this.toggleTranslation}}
        @disabled={{this.isTranslating}}
        @icon="globe"
        @label={{if @showLabel this.title}}
        @title={{this.title}}
      />
    {{/if}}
  </template>
}
