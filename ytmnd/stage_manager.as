/**
 * YTMND "Stage Manager"
 *
 * This class is for keeping track of displayObjects across window resizes. When the
 * window size changes, this class will go through all of the objects it manages and moves them around
 * or scale them as needed. It is also in charge of tiling static and animated images.
 *
 * This class is a real work in progress and needs a good amount of cleanup.
 *
 * @package ytmnd
 * @author max goldberg <max@ytmnd.com>
 * @version $Id: stage_manager.as 2312 2011-07-15 10:24:59Z max $ 
 */

package ytmnd
{
  import flash.display.Sprite;
  import flash.display.Stage;
  import flash.display.StageAlign;
  import flash.display.StageScaleMode;
  import flash.display.DisplayObject;
  import flash.display.MovieClip;
  import flash.display.Bitmap;
  import flash.display.BitmapData;
  import flash.geom.Rectangle;
  import flash.geom.Point;
  import flash.events.Event;
  import flash.utils.setTimeout;
  import flash.utils.clearTimeout;
  import flash.display.BlendMode;
	
  public class stage_manager extends Sprite
  {
	 /**
	  * Generic position bitfield contstants.
	  */

    public static const POS_LEFT   = 1;
	 public static const POS_CENTER = 2;
	 public static const POS_RIGHT  = 4;
 
	 public static const POS_TOP    = 8;
    public static const POS_MIDDLE = 16;
	 public static const POS_BOTTOM = 32;

	 public static const TILED = 64;

	 /**
	  * Constants which describe how the position should change on a stage resize
	  *
	  * ABSOLUTE:  position is defined by the above constants and should be moved accordingly.
	  * RELATIVE:  position is defined by its current X/Y and should use that as a relative base.
	  */
	 
  	 public const POSITION_ABSOLUTE = 64;
	 public const POSITION_RELATIVE = 128;

	 /**
	  * Constants which describe how the item should be scaled.
	  *
	  * NONE:   item never changes size, despite the stage size changing
	  * WIDTH:  item should scale horizontally, but not vertically
	  * HEIGHT: item should scale vertically, but not horizontally
	  * AUTO:   automatically scale the item based on the stage's current width and height.
	  */

	 public const SCALING_NONE   = 0;
	 public const SCALING_WIDTH  = 1;
	 public const SCALING_HEIGHT = 2;
	 public const SCALING_AUTO   = 4;
	 
	 /**
	  * Scaling constraints.
	  */
	 
	 //MARK -- NOT USED
	 public var min_width  = 0;
	 public var max_width  = 0;
	 public var min_height = 0;
	 public var max_height = 0;
	 

	/**
	 * A reference to the global stage, since I have yet to figure out what the "best" way of doing this is.
	 *
    * @tag flash_quirk
	 */

	 public var stageRef:Stage;


	 /**
	  * An array of all the displayObjects we are currently managing.
	  */

	 public var displayObjects:Array = new Array();

	 /**
	  * An array of all the displayObjects which are being tiled.
	  */

	 public var tiles:Array = new Array();

	 /**
	  * A timer to keep track of when tiles need to be redrawn.
	  */

	 public var retile_timer:uint;


	/**
	 * Generic constructor.
	 */	 

    public function stage_manager (stageRef:Stage)
	 {
		 this.stageRef = stageRef;
       //this.stageRef.addEventListener(Event.RESIZE, this.resize_handler); 
	 }

	/**
  	 * Add an item to the stage manager.
  	 */
	 
	 public function add_item (item:DisplayObject, position:Number, scaling:Number, scaling_sizes = null)
	 {
		 var scaling_info:Array = new Array();
		 scaling_info.push(scaling);

		 if (scaling > 0) {
			 var height_ratio = 0;
			 var width_ratio = 0;
			 
			 if (scaling & SCALING_HEIGHT || scaling & SCALING_AUTO) {
				 height_ratio = (item.height/stageRef.stageHeight);
			 }
			 
			 if (scaling & SCALING_WIDTH || scaling & SCALING_AUTO) {
				 width_ratio  = (item.width/stageRef.stageWidth);
			 }
			
			 //MARK
			 if (typeof scaling_sizes == 'Array') {
			 	scaling_info = scaling_info.concat(scaling_sizes);
			 }
		 }
		 
		var i = this.displayObjects.push([item, position, scaling_info]);
		 //item.addEventListener(Event.REMOVED_FROM_STAGE,clean_up);
		this.resize_item(this.displayObjects[i-1][0], this.displayObjects[i-1][2]);
		this.reposition_item(this.displayObjects[i-1][0], this.displayObjects[i-1][1]);
		
	 }
	
	public function remove_item (item:DisplayObject) {
		for (var f in this.displayObjects) {
			if (this.displayObjects[f][0] == item) {
				this.displayObjects.splice(f, 1);
			}
		}
	}
	
	 public function resize_handler (resize_event:Event)
	 {
		 // loop through items, see what needs to be resized and moved around
		 for (var i in this.displayObjects) {
			 if (this.displayObjects[i][2][0] > 0) {
				 //resize
				 this.resize_item(this.displayObjects[i][0], this.displayObjects[i][2]);
			 }
			 this.reposition_item(this.displayObjects[i][0], this.displayObjects[i][1]);
		 }
		 
		clearTimeout(this.retile_timer);
		this.retile_timer = setTimeout(this.retile, 20);
	 }
	
	 public function resize_item (item:DisplayObject, size_info:Array)
	 {
 		 //trace(item, size_info, " - stage: " + stageRef.stageWidth + "x" + stageRef.stageHeight);
		
		 // check if we have min/max
		 if (size_info.length == 7) {
			 if (stageRef.stageWidth < size_info[4] || stageRef.stageHeight < size_info[6]) {
				 // if the stage is smaller than the minimums of this item's constraints, return;
				 return;
			 }
		 }
		 
		 switch (size_info[0]) {
			 case SCALING_WIDTH:
			 	item.width = this.stageRef.stageWidth;
				item.scaleY = item.scaleX;
			 	break;
				
			 case SCALING_AUTO:
			 	item.width  = this.stageRef.stageWidth;
				item.height = this.stageRef.stageHeight;
		      break;
		 }

	 }
	
	 public function reposition_item (item:DisplayObject, position:Number)
	 {
		 var new_x = 0;
		 var new_y = 0;
		
		 //MARK check for POSITION_RELATIVE here and deal accordingly.
		
		 if (position & POS_MIDDLE) {
			new_y =  Math.round(this.stageRef.stageHeight - item.height)/2; 
		 }
		 else if (position & POS_BOTTOM) {
			 new_y = Math.round(this.stageRef.stageHeight - item.height);
		 }
		 
		 if (position & POS_CENTER) {
			 new_x = Math.round(this.stageRef.stageWidth - item.width)/2;
		 }
		 else if (position & POS_RIGHT) {
			 new_x = Math.round(this.stageRef.stageWidth - item.width);
		 }

		 //MARK hack for center origin points.
		 //item.x = (new_x + (item.width/2));
		 //item.y = (new_y + (item.width/2));
		 item.x = new_x;
		 item.y = new_y;
   	//trace("repositing " + item + " to " + new_x + ", " + new_y + " on " + stageRef.stageWidth + ", " + stageRef.stageHeight);
	}
	
	
	public function tile_item (item, tile_record = null)
   {
		var is_retile:Boolean = false;
	
		if (tile_record !== null) {
			is_retile = true;
		}

		if (item is Bitmap) {
			var x_tiles = Math.ceil(this.stageRef.stageWidth/item.width);
			var y_tiles = Math.ceil(this.stageRef.stageHeight/item.height);

			var bmd = item.bitmapData.clone();

			if (is_retile == false) {
				var tile_bm = new Bitmap();
			}
			else {
				var tile_bm = this.tiles[tile_record][1];
			}

	
			//maximum bitmapdata is 2880
			tile_bm.bitmapData = new BitmapData(Math.min(x_tiles * item.width, 2880), Math.min(y_tiles * item.height, 2880));
			
			for (var x = 0; x <= x_tiles; ++x) {
				for (var y = 0; y <= y_tiles; ++y) {
					tile_bm.bitmapData.copyPixels(bmd, new Rectangle(0, 0, item.width, item.height), new Point(x*item.width, y*item.height));
				}
			}
			if (is_retile == false) {
				this.tiles.push([item, tile_bm]);
			}
			return tile_bm;
		}
		else {
			var b:BitmapData = new BitmapData(item.width, item.height, true, 0x00FF00);

			if (is_retile == false) {
				var tile_sprite = new Sprite();
			}
			else {
				var tile_sprite = this.tiles[tile_record][1];
				tile_sprite.graphics.clear(); // Otherwise, the old fill shows through transparent animations.
				clearTimeout(this.tiles[tile_record][2]);
			}


			tile_sprite.graphics.beginBitmapFill(b);
			tile_sprite.graphics.drawRect(0, 0, this.stageRef.stageWidth, this.stageRef.stageHeight);
			tile_sprite.graphics.endFill();

			var anim_timer:uint;

			if (is_retile == false) {
				var tile_record = this.tiles.push([item, tile_sprite, b, anim_timer]);
				tile_record -= 1;
			}

   	   anim_timer = setTimeout(tileAnim, 40, item, b, tile_sprite, tile_record);

			return tile_sprite;
		}
   }
	
	function tileAnim (item, b, tile_sprite, tile_record)
	{
		b.fillRect(new Rectangle(0,0, b.width, b.height), 0x0000FF);
		b.draw(item);

		this.tiles[tile_record][2] = setTimeout(this.tileAnim, 40, item, b, tile_sprite, tile_record);
	}

	function retile ()
	{
		 for (var i in this.tiles) {
			this.tile_item(this.tiles[i][0], i); 
		 }
	}

  }
}

