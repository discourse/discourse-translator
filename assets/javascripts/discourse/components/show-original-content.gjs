import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

export default class ShowOriginalContent extends Component {
  @service router;
  @tracked active = true;

  @action
  async showOriginal() {
    this.active = !this.active;
    // we'll need to refresh with a param
    // that tells the backend to show the original cooked
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
      >
      </DButton>
    </div>
  </template>
}
