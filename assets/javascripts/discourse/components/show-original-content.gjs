import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { tracked } from "@glimmer/tracking";

export default class ShowOriginalContent extends Component {
  @service router;
  @tracked active = true;

  constructor() {
    super(...arguments);
    this.active = !new URLSearchParams(window.location.search).has("show");
  }

  @action
  async showOriginal() {
    this.active = !this.active;
    window.location.search = this.active ? "" : `show=original`;
  }

  get title() {
    return this.active
      ? "translator.hide_translation"
      : "translator.show_translation";
  }

  <template>
    <div class="discourse-translator_toggle-original">
      <DButton
        @icon="language"
        @title={{this.title}}
        class={{concatClass "btn btn-default" (if this.active "active")}}
        @action={{this.showOriginal}}
      />
    </div>
  </template>
}
