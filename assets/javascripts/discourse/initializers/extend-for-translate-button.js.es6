import PostMenuComponent from 'discourse/components/post-menu';
import { Button } from 'discourse/components/post-menu';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { renderSpinner } from 'discourse/helpers/loading-spinner';

export default {
  name: 'extend-for-translate-button',
  initialize: function() {
    PostMenuComponent.registerButton(function(visibleButtons){
      if (!this.siteSettings.translator_enabled) return;
      if (!this.get('post.can_translate')) return;
      if (!Discourse.User.current()) return;

      let [action, label, opts] = !this.get('isTranslated') ? ['translate', 'translator.view_translation'] : ['hideTranslation', 'translator.hide_translation', { className: 'translated' }];
      return visibleButtons.splice(0, 0, new Button(action, label, 'globe', opts));
    });

    PostMenuComponent.reopen({
      isTranslated: false,

      @observes('isTranslated', 'post.can_translate')
      toggleTranslation() {
        this.rerender();
      },

      clickTranslate: function(post) {
        const self = this;
        this.set('isTranslated', true);
        post.set("translated_text", true);

        Discourse.ajax('/translator/translate', {
          type: 'POST',
          data: { post_id: post.get('id') }
        }).then(function(res) {
          post.setProperties({
            "translated_text": res.translation,
            "detected_lang": res.detected_lang
          });
        }).catch(function(error) {
          popupAjaxError(error);
          post.set("translated_text", null);
          self.set('isTranslated', false);
        });

        return false;
      },

      clickHideTranslation: function(post) {
        post.set("translated_text", null);
        this.set('isTranslated', false);
        return false;
      }
    });
  }
};
