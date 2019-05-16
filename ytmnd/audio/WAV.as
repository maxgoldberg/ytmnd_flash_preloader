/**
 * Actionscript to allow Flash to play WAVs
 */

package ytmnd.audio
{
  import flash.errors.EOFError;
  import com.automatastudios.audio.audiodecoder.events.AudioDecoderEvent;
  import com.automatastudios.audio.audiodecoder.events.AudioDecoderEvent;
  import flash.events.EventDispatcher;
  import flash.events.Event;
  import flash.events.ProgressEvent;
  import flash.errors.EOFError;
  import flash.net.URLStream;
  import flash.utils.ByteArray;
  import flash.utils.Endian;

  public class WAV
  {
    private var riff_data:ByteArray;
    private var current_size:uint     = 0;
    private var chunk_size:uint       = 0;
    private var current_position:uint = 0;
    private var start_position:uint   = 0;
    private var data_complete:Boolean = false;
    private var data_size:uint        = 0;
    public var data_chunk:Object      = new Object();
    private var chunks:Array          = new Array();
    private var audio_format          = new Object();
    public var num_samples:Number     = 0;
    public var cache:Array            = new Array();
    public var cache_samples:Array    = new Array();
    public static var counter:Number  = 0;
    private var position_stack:Array  = new Array();
    private var size_stack:Array      = new Array();
    private var raw_data:ByteArray    = new ByteArray();
    private var raw_position:uint     = 0;


    public function WAV (data:ByteArray = null)
    {
      riff_data = data;
      data_size = riff_data.length;
      parse_file();
    }

    public function parse_chunk() :Object
    {
      var chunkInfo:Object = new Object();

      riff_data.endian = Endian.BIG_ENDIAN;

      chunkInfo.start_position = current_position;

      /**
       * Grab the 4 byte chunk descriptor.
       */

      chunkInfo.chunkId = String.fromCharCode(riff_data.readUnsignedByte(), riff_data.readUnsignedByte(), riff_data.readUnsignedByte(), riff_data.readUnsignedByte());
      current_position += 4;

      riff_data.endian = Endian.LITTLE_ENDIAN;

      /**
       * Grab the 4 byte size of this chunk.
       */

      chunkInfo.size = riff_data.readUnsignedInt();
      current_position += 4;

      /**
       * Grab the chunk data into a bytearray.
       */

      trace('PARSED ', chunkInfo.chunkId, 'SIZE ', chunkInfo.size, riff_data.position, chunkInfo.start_position);
      //trace(current_position, riff_data.position, chunkInfo.size);

      chunkInfo.data = new ByteArray();
      chunkInfo.endian = Endian.LITTLE_ENDIAN;

      riff_data.readBytes(chunkInfo.data, 0, chunkInfo.size);

      chunkInfo.end_position = riff_data.position - chunkInfo.start_position;

      chunks.push(chunkInfo);

      return chunkInfo;
    }

    public function parse_file()
    {
      var chunkInfo = parse_chunk();

      if (chunkInfo.chunkId == 'RIFF') {

        /**
         * Look for WAV subchunk.
         */

        chunkInfo = new Object();
        riff_data.position = current_position;
        riff_data.endian = Endian.BIG_ENDIAN;
        var wav_id = String.fromCharCode(riff_data.readUnsignedByte(), riff_data.readUnsignedByte(), riff_data.readUnsignedByte(), riff_data.readUnsignedByte());
        current_position += 4;
        riff_data.endian = Endian.LITTLE_ENDIAN;

        if (wav_id == "WAVE") {
          riff_data.position = current_position;
          chunkInfo = parse_chunk();



          while (chunkInfo.chunkId != 'fmt ') {
            riff_data.position = current_position;
            chunkInfo = parse_chunk();
          }


          if (chunkInfo.chunkId == 'fmt ') {

            /**
             * Parse format data.
             */

            chunkInfo.data.endian = Endian.LITTLE_ENDIAN;
            chunkInfo.data.position = 0;

            audio_format.format           = (chunkInfo.data.readUnsignedShort() == 1 ? "PCM" : "Unknown");
            audio_format.channels         = chunkInfo.data.readUnsignedShort();
            audio_format.sampleRate       = chunkInfo.data.readUnsignedInt();
            audio_format.bitRate          = chunkInfo.data.readUnsignedInt()/8;
            audio_format.blockAlign       = chunkInfo.data.readUnsignedShort();
            audio_format.bitsPerSample    = chunkInfo.data.readUnsignedShort();
            audio_format.sampleMultiplier = 44100 / audio_format.sampleRate;

            var result:String = "";

            result += "format: " + audio_format.format + "\n";
            result += "channels: " + audio_format.channels + "\n";
            result += "sampleRate: " + audio_format.sampleRate + "\n";
            result += "bitRate: " + audio_format.bitRate + "\n";
            result += "blockAlign: " + audio_format.blockAlign + "\n";
            result += "bitsPerSample: " + audio_format.bitsPerSample + "\n";
            result += "sampleMultiplier: " + audio_format.sampleMultiplier + "\n";

            trace("------------------------------\n", result, "------------------------------\n");

            if (audio_format.bitsPerSample == 0) {
                audio_format.bitsPerSample = 8;
            }


            current_position = riff_data.position;
            /**
             * Hop to DATA chunk.
             */

            while (chunkInfo.chunkId != 'data') {
              //riff_data.position = current_position;
              chunkInfo = parse_chunk();
            }

            if (chunkInfo.chunkId == "data") {
              riff_data.position = 0;

              /**
               * We now have the data chunk.
               */

              for (var i=0; i < chunks.length; ++i) {
                if (chunks[i].chunkId == 'data') {
                  this.data_chunk = chunks[i];
                  this.num_samples = data_chunk.data.length / (audio_format.channels * (audio_format.bitsPerSample / 8));
                  convert_wave_data();
                }
              }

            }
            else {
              //invalid WAV
            }
          }
          else {
            //invalid WAV
          }


        }
        else {
          //invalid WAV
        }

      }
      else {
        //invalid WAV
      }
    }

    public function convert_wave_data ():ByteArray
    {
      var i:uint = 0;
      var j:uint = 0;
      var sample:Number;
      var left_sample:Number;
      var right_sample:Number;
     //Subchunk2Size    == NumSamples * NumChannels * BitsPerSample/8
    //var num_samples = data_chunk.data.length / (audio_format.blockAlign * (audio_format.bitsPerSample / 8)) ;
      var num_samples = data_chunk.data.length / (audio_format.channels * (audio_format.bitsPerSample / 8));

      //trace((audio_format.blockAlign * (audio_format.bitsPerSample / 8)), 'penis');

      //* audio_format.channels

      raw_data = new ByteArray();
      data_chunk.data.endian = Endian.LITTLE_ENDIAN;
      raw_data.endian = Endian.LITTLE_ENDIAN;
      data_chunk.position = 0;
      raw_data.position = 0;

      /**
       * Mono.
       */

      trace('encoding data', typeof raw_data);
      trace('audio format',  audio_format.format, audio_format.channels, audio_format.bitsPerSample, audio_format.blockAlign, num_samples);
      trace('data info', data_chunk.data.length, data_chunk.data.position, data_chunk.data.bytesAvailable);

        //trace('done resampling', raw_data.length, data_chunk.data.length, "|", raw_data, "|");

      if (audio_format.channels == 1) {
        for (i = 0; i < num_samples; ++i) {

          if (audio_format.bitsPerSample == 8) {
            sample = (data_chunk.data.readUnsignedByte() - 128) / 128;
          }
          else if (audio_format.bitsPerSample == 16) {
            sample = data_chunk.data.readShort() / 32768;
          }

          for (j = 0; j < audio_format.sampleMultiplier; ++j) {
            raw_data.writeFloat(sample);
            raw_data.writeFloat(sample);
          }
        }
      }
      else if (audio_format.channels == 2) {
        /**
         * Stereo.
         */
        for (i = 0; i < num_samples; ++i) {

          if (audio_format.bitsPerSample == 8) {
            sample  = (data_chunk.data.readUnsignedByte() - 128) / 128;

            for (j = 0; j < audio_format.sampleMultiplier; ++j) {
              raw_data.writeFloat(sample);
            }

            sample  = (data_chunk.data.readUnsignedByte() - 128) / 128;

            for (j = 0; j < audio_format.sampleMultiplier; ++j) {
              raw_data.writeFloat(sample);
            }
          }
          else if (audio_format.bitsPerSample == 16) {
            left_sample = data_chunk.data.readShort() / 32767;
            right_sample = data_chunk.data.readShort() / 32767;

            for (j = 0; j < audio_format.sampleMultiplier; ++j) {
              raw_data.writeFloat(left_sample);
              raw_data.writeFloat(right_sample);
            }
          }
        }
      }

      raw_data.position = 0;
      return raw_data;
    }

    public function reset ():void
    {
        raw_data.position = 0;
    }

    public function cache_sample_data ()
    {

        var sample_count = this.num_samples;
        var loops = Math.ceil(this.num_samples/8192);
        var samples_to_get = 8192;


        var num_blocks = Math.ceil(this.num_samples/8192);
        var spb = 0;

        for (var i = num_blocks; i <= 500; ++i) {
            num_blocks++;

            spb = this.num_samples/num_blocks;

            if (Math.floor(spb) == spb) {
                trace("Found working sample rate: " + spb);
                //loops = num_blocks;
                //samples_to_get = spb;
                break;
            }
        }

        trace("Will take ", loops, " loops. (", this.num_samples , " samples)");

        for (i = 0; i < loops; ++i) {

            if (sample_count < 8192) {
                samples_to_get = sample_count;
            }
            else {
                samples_to_get = 8192;
            }


            sample_count -= samples_to_get;
            cache[i] = new ByteArray();
            cache_samples[i] = samples_to_get;

            trace("Getting sample data [", samples_to_get, " samples] loop #" + i);

            get_sample_data(0, samples_to_get, cache[i]);

            trace("Got sample data: " + cache[i].length + " bytes.");
            trace("Which is: " + this.cache[i].length / (audio_format.channels * (audio_format.bitsPerSample / 8)) + " samples");

        }
    }

    public function get_cached_sample_data(sampleData:ByteArray):void
    {

        cache[counter].position = 0;

        this.cache[counter].endian = Endian.LITTLE_ENDIAN;
        sampleData.endian = Endian.LITTLE_ENDIAN;

        trace("counter at " + counter);

        var sample_count = this.cache[counter].length / (audio_format.channels * (audio_format.bitsPerSample / 8)) ;

        trace("READING " + sample_count + " FROM BA " + this.cache[counter].length + " len " + cache_samples[counter]);



        for (var i=0; i < cache_samples[counter]; ++i) {
            sampleData.writeFloat(this.cache[counter].readFloat());
        }


        //sampleData = this.cache[counter];

        trace(sampleData.length);

        //cache[counter].readBytes(sampleData, 0, cache[counter].length);


        counter++;

        if (counter == this.cache.length) {
            counter = 0;
        }

        trace("counter now at " + counter);

    }


    public function get_sample_data (position:Number, numSamples:uint, sampleData:ByteArray):void
    {
      var overflow:int = 0;
      var numBytes = numSamples * audio_format.blockAlign * 2;
      var max_read = 0;


      var numFloats = numBytes/4;
      //var numFloats = numBytes/(2 * (audio_format.bitsPerSample / 8));

      trace("READING " + numFloats + " starting at position " + raw_data.position, raw_data.bytesAvailable);

      raw_data.endian = Endian.LITTLE_ENDIAN;
      sampleData.endian = Endian.LITTLE_ENDIAN;

      //trace(numFloats, numBytes, raw_data.bytesAvailable, numSamples);

      if (numBytes > raw_data.bytesAvailable) {
        overflow = (numBytes - raw_data.bytesAvailable)/4;
        numFloats -= overflow;
      }


      for (var i=0; i < numFloats; ++i) {
        sampleData.writeFloat(raw_data.readFloat());
      }

      //trace("overflow is " + overflow);
      if (overflow > 0) {


        while (overflow > 0) {

        if ((raw_data.bytesAvailable/4) > overflow) {
            max_read = raw_data.bytesAvailable/4;
        }
        else {
            max_read = overflow;
        }

        //trace("MAXIMUM READ IS ", max_read, " RAW_DATA LENGTH IS ", raw_data.length,raw_data.bytesAvailable );


        raw_data.position = 0;
        for (var i=0; i < max_read; ++i) {
          sampleData.writeFloat(raw_data.readFloat());
        }

        overflow -= max_read;
        }

        //position = raw_data.position;
      }



      //trace("BYTES AVAILABLE = ", sampleData.length);
    }
  }
}
