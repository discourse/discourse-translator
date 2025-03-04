import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

export default class ShowOriginalContent extends Component {
  static shouldRender(args) {
    return args.topic.is_translated;
  }

  @service router;
  @tracked isTranslated = true;

  constructor() {
    super(...arguments);
    this.isTranslated = !new URLSearchParams(window.location.search).has(
      "show"
    );
  }

  @action
  async showOriginal() {
    const params = new URLSearchParams(window.location.search);
    if (this.isTranslated) {
      params.append("show", "original");
    } else {
      params.delete("show");
    }
    window.location.search = params.toString();
  }

  get title() {
    return this.isTranslated
      ? "translator.content_translated"
      : "translator.content_not_translated";
  }

  <template>
    <div class="discourse-translator_toggle-original">
      <DButton
        @icon="language"
        @title={{this.title}}
        class={{concatClass "btn btn-default" (if this.isTranslated "active")}}
        @action={{this.showOriginal}}
      />
    </div>
  </template>
}
