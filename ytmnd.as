/* -*- C++ -*- */

/**
 * YTMND Headless Loader
 *
 * Master document class.
 *
 * This class is formatted in a format to make popping hooks all along the process fairly easy.
 * For the most part, these functions are all blocking to avoid having to kill cycles waiting
 * for timers. Below is a list of the major hook points and functions that are called before
 * and after each to give a quick idea of what's going on.
 *
 * SWF_LOAD - Master SWF has finished loading
 *    + main_swf_loaded()
 *    + init_loader()
 *
 * DATA_LOAD - Load and parse relevant data about the assets from the JavaScript interface.
 *    + post_asset_loaded_hook()
 *
 *
 * ASSETS_LOAD - Site sound, images, etc are loaded (check_load_status() is run during)
 *    + post_asset_load_hook()
 *    + pre_show_ytmnd_hook()
 *
 * @author max goldberg <max@ytmnd.com>
 * @version $Id: ytmnd.as 2312 2011-07-15 10:24:59Z max $
 */

package {
  import flash.display.MovieClip;
  import flash.display.Loader;
  import flash.display.LoaderInfo;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageScaleMode;
  import flash.events.*;
  import flash.media.SoundChannel;
  import flash.system.Security;
  import flash.text.TextField;
  import flash.utils.setTimeout;
  import flash.utils.setInterval;
  import flash.utils.clearTimeout;
  import ytmnd.asset_loader;
  import ytmnd.stage_manager;
  import flash.utils.getDefinitionByName;
  import flash.external.ExternalInterface;

  public class ytmnd extends MovieClip
  {
    /**
     * Basic Site data
     */

    public var background_image:MovieClip;
    public var foreground_image:MovieClip;
    public var sound:MovieClip;
    public var sound_url:String;
    public var sound_extension:String;

    /**
     * Disposable variables for tracking the loading status of site assets.
     */

    public var status_total_bytes:Number = 0;
    public var status_total_bytes_loaded:Number = 0;
    public var status_percent:Number = 0;
    public var status_timer:uint;

    /**
     * Stage Manager object which keeps track of displayobjects with a dynamic placement and
     * some constants to make common placements a bit easier to look at.
     */

    public var stage_man = new stage_manager(stage);
    public const POS_CENTERED    = ytmnd.stage_manager.POS_CENTER+ytmnd.stage_manager.POS_MIDDLE;
    public const POS_TOP_LEFT    = ytmnd.stage_manager.POS_LEFT+ytmnd.stage_manager.POS_TOP;
    public const POS_TOP_RIGHT   = ytmnd.stage_manager.POS_RIGHT+ytmnd.stage_manager.POS_TOP;
    public const POS_BOTTOM_LEFT = ytmnd.stage_manager.POS_LEFT+ytmnd.stage_manager.POS_BOTTOM;

    /**
     * SoundChannel object used to play MP3 files.
     */

    public static var sound_channel:SoundChannel;

    /**
     * Advertisement boolean. Will externally be sent to flash when the ad is showing.
     */

    public var advertisement:Boolean = false;

    /**
     * If the advertisement has a forced viewing time, this keeps track of how much time is left before the user can proceed.
     */

    public var advertisement_time_left:Number = 0;


    /**
     * SWF stage elements.
     */

    public var global_play_button:MovieClip;
    public var loading_status:MovieClip;
    public var load_timeout;


    /**
     * Generic document constructor.
     *
     * Don't reference any stage instances here as this function will run BEFORE the entire SWF
     * is loaded. So if you try to access or reference stage objects which were automatically declared,
     * you will get errors.
     */

    public function ytmnd()
    {
      /**
       * I'm not sure if any of these actually work.
       */

      /*
        Security.allowDomain("content.ytmndev.com");
        Security.allowDomain("content.ytmnd.com");
        Security.loadPolicyFile("http://content.ytmndev.com/crossdomain.xml");
        flash.system.Security.allowDomain("content.ytmnd.com");
        flash.system.Security.allowDomain("content.ytmndev.com");
        flash.system.Security.allowDomain("ytmnd.com");
        flash.system.Security.allowDomain(".ytmnd.com");
        flash.system.Security.allowDomain("*.ytmnd.com");
        flash.system.Security.allowDomain("*.ytmndev.com");
        flash.system.Security.allowDomain(".ytmndev.com");
      */

      flash.system.Security.allowDomain("*");

      /**
       * We manage scaling manually.
       */

      stage.scaleMode = StageScaleMode.NO_SCALE;
      stage.align     = StageAlign.TOP_LEFT;

      /**
       * Set up JavaScript interface.
       */

      ExternalInterface.addCallback("hand_off_assets", ext_hand_off_assets);
      ExternalInterface.addCallback("showing_aids",    ext_showing_ad);
      ExternalInterface.addCallback("hide_flash",      ext_hide_flash);
      ExternalInterface.addCallback("stop_sound",      ext_stop_sound);
      ExternalInterface.addCallback("start_sound",     ext_start_sound);


      ExternalInterface.call("ytmnd.site.loader.flash_loaded");
      main_swf_loaded();
    }

    // FUCK FLASH. IT IS A GARBAGE PIECE OF SHIT LANGUAGE.

    public function get_stage_instance (name:String):MovieClip
    {
      return new (getDefinitionByName(name))();
    }

    /**
     * This function is called when the SWF itself is finished loading and in memory.
     *
     * It is okay to reference automatically declared stage objects here (assuming they are on frame 1);
     */

    public function main_swf_loaded ():void
    {
      ExternalInterface.call("ytmnd.site.loader.trace", 'main_swf_loaded() fired off.');
      //trace('main_swf_loaded fired');
      this.addFrameScript(1, init_loader);
      this.gotoAndStop(2);
    }

    /**
     * Initialize the loader.
     *
     * Hide anything that isn't relevant, it's show time.
     * Fires off the function that grabs all the necessary data from the external XML interface.
     */

    private function init_loader()
    {
      ExternalInterface.call("ytmnd.site.loader.trace", 'init_loader() fired off.');
      //trace('init_loader fired');

      /**
       * Show the loading movie.
       */

      this.loading_status = this.get_stage_instance('loading_status');
      this.loading_status.status_numbers.text = '';
      this.addChild(this.loading_status);
      this.stage_man.add_item(this.loading_status, POS_TOP_LEFT, 0);
      this.loading_status.status_generic.text = "Loading site info...";
      this.loading_status.status_logo.gotoAndStop(1);
      this.loading_status.status_generic.visible = true;

      /**
       * Ccheck for the JavaScript interface, and if it is, tell it we are ready to load assets.
       */

      if (ExternalInterface.call("ytmnd.site.loader.flash_js_check") != 1) {
        this.loading_status.status_generic.text = "You must enable JavaScript to view this page.";
      }
      else {
        ExternalInterface.call("ytmnd.site.loader.flash_ready_for_assets");
        ExternalInterface.call("ytmnd.site.loader.trace", 'Waiting on external asset handoff.');
        //trace('waiting for external asset handoff...');
      }
    }

    /**
     * External function which javascript uses to pass asset info in.
     */

    private function ext_hand_off_assets (background:String, foreground:String, sound:String):Boolean
    {
      this.load_site_assets(background, foreground, sound);
    }


    /**
     * External function which javascript will use to tell us it is showing an ad, and this is how long we should delay for.
     */

    private function ext_showing_ad (ms:Number)
    {
      this.advertisement = true;
      this.advertisement_time_left = ms;
      this.wait_for_advertisement();
    }



    /**
     * Generic hook for once the advertisement has loaded. Counts down to 0 and then does nothing.
     */

    private function wait_for_advertisement():void
    {
      if (this.advertisement_time_left > 0) {
        var ad_countdown = function() {
          advertisement_time_left -= 100;

          if (advertisement_time_left <= 0) {
            advertisement_time_left = 0;
          }
          else {
            setTimeout(ad_countdown, 100);
          }};

        setTimeout(ad_countdown, 100);
      }
    }


    /**
     * Start the actual loading, and watch the status.
     */

    private function load_site_assets (background:String, foreground:String, sound:String):void
    {
      ExternalInterface.call("ytmnd.site.loader.trace", 'Loading site assets.');
      //trace('loading site assets...');

      this.sound_extension = sound.substr(-3);

      this.loading_status.status_generic.text = "Loading site junk...";
      this.sound            = new ytmnd.asset_loader(sound, sound.substr(-3));
      this.foreground_image = new ytmnd.asset_loader(foreground);

      if (background != '') {
        this.background_image = new ytmnd.asset_loader(background);
      }
      else {
        this.background_image = new MovieClip();
        this.background_image.completed = true;
        this.background_image.bytes_total = 0;
        this.background_image.bytes_loaded = 0;
      }

      this.status_timer = setTimeout(check_load_status, 10);
      this.loading_status.status_logo.gotoAndStop(1);
      this.loading_status.visible = true;
    }

    /**
     * Status function which updates the loader bar and keeps calling itself until all the assets are loaded.
     */

    public function check_load_status():void
    {
      var b_total;
      var b_loaded;

      b_total = Math.round(this.sound.bytes_total + this.foreground_image.bytes_total + this.background_image.bytes_total);
      b_loaded = Math.round(this.sound.bytes_loaded + this.foreground_image.bytes_loaded + this.background_image.bytes_loaded);

      if (this.status_total_bytes == 0) {
        if (!isNaN(b_total) && !isNaN(b_loaded)) {
          this.status_total_bytes =  b_total/1000;
          this.status_total_bytes_loaded = b_loaded/1000;
          this.loading_status.status_numbers.visible = true;
          this.loading_status.status_generic.visible = true;
        }
        else {
          this.status_timer = setTimeout(check_load_status, 10);
          return;
        }
      }

      this.status_total_bytes =  b_total/1000;
      this.status_total_bytes_loaded = b_loaded/1000;

      this.status_percent = Math.floor(this.status_total_bytes_loaded/this.status_total_bytes * 100);
      this.loading_status.status_logo.gotoAndStop(this.status_percent);
      this.loading_status.status_numbers.text = this.status_percent + "% - " + Math.round(this.status_total_bytes_loaded) + "kB/ " + Math.round(this.status_total_bytes) + "kB ";

      //ExternalInterface.call("update_load_status", this.status_total_bytes, this.status_total_bytes_loaded, this.loading_status.status_numbers.text);

      if (this.sound.completed == false || this.foreground_image.completed == false || this.background_image.completed == false) {
        this.status_timer = setTimeout(check_load_status, 10);
      }
      else {
        clearTimeout(this.status_timer);
        ExternalInterface.call("ytmnd.site.loader.trace", 'Done loading site assets.');
        //trace('done loading assets.');
        this.post_asset_load_hook();
      }
    }


    /**
     * Generic hook function which is called once the site's assets are fully loaded.
     */

    private function post_asset_load_hook ():void
    {
      /**
       * Let JavaScript know we're all loaded.
       */

      ExternalInterface.call("ytmnd.site.loader.flash_assets_loaded");

      if (this.advertisement_time_left > 0) {

        /**
         * If the advertisement's forced wait hasn't elapsed yet, pop out to the looping timer until it has elapsed.
         */

        waiting_for_advertisement_finish(post_asset_load_hook);
      }
      else {
        /**
         * Tell the JS we're ready to go!
         */

        ExternalInterface.call("ytmnd.site.loader.flash_ad_wait_over", this.advertisement, this.advertisement_time_left);
        this.loading_status.status_generic.text = "Waiting for your dumb computer...";
      }
    }

    /**
     * Self referential function to wait until an advertisement's forced wait has elapsed.
     *
     * Updates status text with leftover?
     */

    private function waiting_for_advertisement_finish (followup_function:Function):void
    {
      if (this.advertisement_time_left > 0) {
        this.loading_status.status_generic.text = "Check out this ad...";
        this.loading_status.status_numbers.text = 'ETA ' + Math.ceil(this.advertisement_time_left/1000) + 's';
        setTimeout(waiting_for_advertisement_finish, 10, followup_function);
      }
      else {
        followup_function();
      }
    }


    /**
     * Generic hook function which should be fired off directly before a YTMND starts.
     */

    private function ext_hide_flash ():Boolean
    {
      this.stage_man.remove_item(this.loading_status);
      this.loading_status.visible = false;

      return true;
    }


    /**
     * External hooks to start and stop sound.
     */

    public function ext_stop_sound () :void
    {
      if (this.sound_extension == 'mp3' || this.sound_extension == 'wav') {
        sound_channel.stop();
      }

      if (this.sound_extension == 'wav') {
        this.sound.WAV.reset();
      }
    }

    public function ext_start_sound () :void
    {
      if (this.sound_extension == 'mp3') {
        sound_channel = this.sound.clip.play(0, 0xFFFFFE, null);
      }
      else if (this.sound_extension == 'wav') {
        sound_channel = this.sound.clip.play();
      }
    }
  }
}
