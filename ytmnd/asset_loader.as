package ytmnd
{
    import flash.display.Loader;
    import flash.display.LoaderInfo;
    import flash.display.MovieClip;
    import flash.events.*;
    import flash.media.Sound;
	import flash.net.URLRequest;
	import flash.net.URLStream;	
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;	
 	import flash.net.LocalConnection;
	import flash.system.Security;
	import flash.system.LoaderContext;
	import flash.utils.ByteArray;
    import ytmnd.audio.WAV;

    public class asset_loader extends MovieClip
    {
        public var url:String;
        public var bytes_total:Number;
        public var bytes_loaded:Number;
        public var percent:Number;
        public var completed:Boolean = false;
        
        public var clip;//:Loader;// = new Loader();
        public var clip_info:LoaderInfo;
		public var clip_stream:URLStream;
		public var clip_loader:URLLoader;		
		public var followup_function:Function = null;
		public var WAV;

		  
		public var asset_type = '';
		  
		public var lc_remote:LocalConnection = new LocalConnection();

        public function asset_loader (url:String, file_type:String = 'swf', followup_function:Function = null)
        {
            this.url = url;
            var request:URLRequest = new URLRequest(url);
			  
				if (file_type == 'swf') {
					this.clip = new Loader();
  	                this.clip_info = LoaderInfo(this.clip.contentLoaderInfo);
					var loader_context = new LoaderContext(true);
 
   	                this.clip_info.addEventListener(Event.INIT, initHandler);
   	                this.clip_info.addEventListener(ProgressEvent.PROGRESS,progressHandler);
	                this.clip_info.addEventListener(Event.COMPLETE, completionHandler);         
	                this.clip_info.addEventListener(IOErrorEvent.IO_ERROR,errorHandler);
	                this.clip.load(request,loader_context);
				}
				else if (file_type == 'mp3') {				 
					this.clip = new Sound();
	                this.clip.addEventListener(Event.INIT, initHandler);
	                this.clip.addEventListener(ProgressEvent.PROGRESS,progressHandler);
	                this.clip.addEventListener(Event.COMPLETE, completionHandler);         
	                this.clip.addEventListener(IOErrorEvent.IO_ERROR,errorHandler);
					this.clip.load(request);
				}
				else if (file_type == 'wav') {
					/*
				     this.clip_stream = new URLStream();
					 this.clip = new AudioDecoder();
					 this.clip_stream.addEventListener(Event.INIT, initHandler);
 	                 this.clip_stream.addEventListener(ProgressEvent.PROGRESS,progressHandler);
	                 this.clip_stream.addEventListener(Event.COMPLETE, completionHandler);         
	                 this.clip_stream.addEventListener(IOErrorEvent.IO_ERROR,errorHandler);
					 this.clip.load(this.clip_stream,WAVDecoder, 8000);
					 this.clip_stream.load(request);
					 */	
					
                    this.clip = new URLLoader();
  	                this.clip.dataFormat = URLLoaderDataFormat.BINARY;
					this.clip.addEventListener(Event.INIT, initHandler);
   	                this.clip.addEventListener(ProgressEvent.PROGRESS,progressHandler);
	                this.clip.addEventListener(Event.COMPLETE, wavCompletionHandler);         
	                this.clip.addEventListener(IOErrorEvent.IO_ERROR,errorHandler);
	                this.clip.load(request);
				}
			
				this.followup_function = followup_function;
        }
		
		private function wavCompletionHandler (event:Event) :void
		{
			trace(this.clip, " - COMPLETE");
			var wavData = this.clip.data;
			this.WAV = new ytmnd.audio.WAV(wavData);
			//this.WAV.cache_sample_data();
			
			this.clip = new Sound();
		    this.clip.addEventListener(SampleDataEvent.SAMPLE_DATA, function(event){
				//WAV.get_sample_data(event.position, 4090, event.data);
				WAV.get_sample_data(event.position, 8192, event.data);
				//WAV.get_cached_sample_data(event.data);
				
			});
			
			//SoundEvent.SOUND_UPDATE
			this.clip.addEventListener(Event.INIT,  function(event:Event){trace(Event.toString(), 'in INIT');});
	        this.clip.addEventListener(ProgressEvent.PROGRESS,  function(event:Event){trace(Event.toString(), 'in PROGRESS');});
	        this.clip.addEventListener(Event.COMPLETE,  function(event:Event){trace(Event.toString(), 'in COMPLETE');});
	        this.clip.addEventListener(IOErrorEvent.IO_ERROR, function(event:Event){trace(Event.toString(), 'in ERROR');});
			this.clip.addEventListener(Event.OPEN, function(event:Event){trace(Event.toString(), 'in OPEN');});
																							   

			this.completed = true;
		}

        private function completionHandler (event:Event):void
        {
   		    trace(this.clip, " - COMPLETE");
            this.completed = true;
				if (this.followup_function !== null) {
					this.followup_function();
				}
        }

        
        private function progressHandler(event:ProgressEvent):void
        {
            this.bytes_loaded = event.bytesLoaded;
            this.bytes_total  = event.bytesTotal;
            this.percent = Math.floor(bytes_loaded / bytes_total * 100);
            
            //trace("progress: " + event.bytesLoaded + " " + event.bytesTotal + " " + this.percent);
        }
        
        private function initHandler(event:Event):void
        {
			trace(this.clip, " - INIT");

			
            //var loader:Loader   = Loader(event.target.loader);
            //var info:LoaderInfo = LoaderInfo(loader.contentLoaderInfo);
        }

        private function errorHandler(event:IOErrorEvent):void
        {
            trace("ioErrorEvent dong: " + event);
        }
    }
}
