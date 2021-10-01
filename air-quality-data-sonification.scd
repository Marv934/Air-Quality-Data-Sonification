// Source AQI (Air Quality Index):
//  - https://en.wikipedia.org/wiki/Air_quality_index
//  - https://airindex.eea.europa.eu

// Todo:
// How To check if a Synth is running?

// Todo GUI:
// - Box to Slider update

// Setting up the Server

//////////////////////////////////////////////////////////////////////////////////
// Version 0.4


// Start AQI Synths
var start_aqi_synth = {
	Array.fill(6, {arg i;
		//var fr = freq * aqi_scale[i];
		Synth( \SimpleSine, [\freq, 0, \amp, 0] );
	});
};

// Set AQI Synth AMP
var map_aqi_to_amp = { arg aqi, synth;
	// Loop trough all Synth
	6.do({ arg i;
		var ampli;
		if( aqi < aqi_band[i+1] , {
			if( aqi > aqi_band[i], {
				// If AQI in Band - Calculate Amplitude
				ampli = amp * ( (aqi-aqi_band[i])/(aqi_band[i+1]-aqi_band[i]) );
			}, {
				// If AQI lower than Band, set Amplitude to 0
				ampli = 0;
			});
		}, {
			// If Aqi higher than Band, set Amplitude to Global Value
			ampli = amp;
		});
		synth[i].set(\amp, ampli);
	});
};

// Set AQI Synth Freq
var map_scale_to_freq = { arg synth;
	6.do({ arg i;
		var fr = freq * aqi_scale[i];
		synth[i].set(\freq, fr);
	});
};

//--------------
//- Init Tasks -
//--------------
var play_set = Task({
	var t_play = 60/bpm;
	data.do({ arg value, counter;
		"PM2.5: ".post;
		value.postln;
		map_aqi_to_amp.value(value, synth_sonification);
		t_play.wait;
	});
	synth_sonification.do({ arg synth;
		synth.free;
	});
});



// Start/Stop Sonification
var start_sonification = {arg state;
	if( state.value == 1 , {
		start_reference_synth.value;
		// kill testing synth if running
		if( synth_testing_running, {
			"Stop Testing Synth".postln;
			synth_testing.do({ arg synth;
				synth.free;
			});
		});

		// Start AQI Synths
		synth_sonification = start_aqi_synth.value();
		map_scale_to_freq.value(synth_sonification);

		// Run Task
		play_set.play;
	}, {
		stop_reference_synth.value;

		// Stop Routine
		play_set.stop;
		play_set.reset;

		// Stop AQI Synths
		synth_sonification.do({ arg synth;
			synth.free;
		});
	});
};
)


(
SynthDef( \Reference, {arg freq = 440, amp = 0.5;
	Out.ar( [0, 1] , SinOsc.ar(freq, 0, amp, 0));
}).add;

SynthDef( \AQI, {arg freq = 440, freqmul = 1, amp = 0.5, ampmul = 1;
	Out.ar( [0, 1] , SinOsc.ar(freq * freqmul, 0, amp * ampmul, 0));
}).add;
)


(
//---------------
//- Init Busses -
//---------------
var fundfreq = Bus.control(s, 1);
var fundamp = Bus.control(s, 1);

//---------------------------------
//- Init GUI and Setup Appearance -
//---------------------------------

// set Fonts
var h1 = Font.new( size: 18, bold: true );

//-------------------------------
//- Start Audio setting section -
//--------------------------------
// Fundamental Frequency Settings
var spec_fundfreq = ControlSpec( 60, 10000, \exp, 1 );

var win_fundfreq_box = NumberBox().align_( \right )
.action_({ arg num;
	fundfreq.value = num.value;
} )
.valueAction_( 440 ).clipLo_( 60 ).clipHi_( 10000 );

var win_fundfreq_slider = Slider()
.action_( {
	win_fundfreq_box.valueAction_( spec_fundfreq.map( win_fundfreq_slider.value ) )
} )
.value_( spec_fundfreq.unmap( 440 ) );

// Fundamental Amplitude Settings
var win_fundamp_box = NumberBox().align_( \right )
.action_({ arg num;
	fundamp.value = num.value;
} )
.valueAction_( 0.5 ).clipLo_( 0 ).clipHi_( 1 );

var win_fundamp_slider = Slider()
.action_( {
	win_fundamp_box.valueAction_( win_fundamp_slider.value )
} )
.value_( 0.5 );

// Frequency Mappig Selection
var array_scale = [
	[3/2, 9/4, 27/8, 81/16, 243/32, 729/64],
	[3/2, 9/8, 27/16, 81/64, 243/128, 729/512],
	[2, 3, 4, 5, 6, 7],
	[3/2, 81/64, 243/128, 4/3, 243/128, 9/8]
];

var win_scale_select = ListView()
.valueAction_( 0 ).selectionMode_( \single )
.items_( [
	"Fifth Shift",
	"Fifth Shift - One Oktave",
	"Overtones",
	"Dur Tonic",
] );

// Partikel Breakpoint selection
var aqi_spec;

var array_breakpoints = [
	[0, 20, 40, 50, 100, 150, 1200], // PM 10
	[0, 10, 20, 25, 50, 75, 800] //PM 2.5
];

var win_breakpoints_select = ListView()
.action_( { arg sel;
	aqi_spec = Array.fill( array_breakpoints[ sel.value].size - 1, {arg i;
		ControlSpec(
			array_breakpoints[sel.value][i],
			array_breakpoints[sel.value][i+1],
			\lin, 1
		);
	} );
})
.items_( [
	"PM 10",
	"PM 2.5",
] )
.selectionMode_( \single )
.valueAction_( 0 );

//-----------------------
// Audio Setting Layout
var win_settings_audio = GridLayout.columns(
	[
		StaticText().string_("Fundamental Frequency").align_(\center),
		win_fundfreq_slider,
		win_fundfreq_box
	], [
		StaticText().string_("Fundamental Amplitude").align_(\center),
		win_fundamp_slider,
		win_fundamp_box
	], [
		StaticText().string_("Select Scale"),
		win_scale_select
		// Maybe selection of lin/log/const Amplitude Mapping
	], [
		StaticText().string_("Select Breakpoints"),
		win_breakpoints_select
	]
);
//----------------------------
// End Audio setting section -
//----------------------------

//------------------------
// Start Testing section -
//------------------------
// Set data value slider
var test_ampmul = Array.fill( array_scale[ win_scale_select.value ].size, {arg i;
	Bus.control(s, 1).value_(0);
} );

var win_testdata_box = NumberBox().align_( \right )
.action_( { arg num;
	aqi_spec.do( { arg spec, i;
		test_ampmul[i].value = ( spec.unmap( num.value ) );
	} );
} )
.valueAction_( 0 );

var win_testdata_slider = Slider().orientation_( \horizontal )
.action_( {
	var spec_testdata = ControlSpec(
		array_breakpoints[win_breakpoints_select.value][0],
		array_breakpoints[win_breakpoints_select.value][6],
		\lin, 1
	);
	win_testdata_box.valueAction_( spec_testdata.map( win_testdata_slider.value ) )
} )
.value_( 0 );

// Referene Tone Start/Stop Button
var reference;

var win_reference_btn = Button()
.action_( { arg state;
	if( state.value == 1, {
		reference = Synth( \Reference );
		reference.map(\freq, fundfreq.index);
		reference.map(\amp, fundamp.index);
	}, {
		reference.free;
		reference = nil;
	});
} )
.states_( [["Start Reference", Color.black, Color.green], ["Stop Reference", Color.black, Color.red]] );

// Referene Tone Start/Stop Button
var test;

var win_test_btn = Button()
.action_( { arg state;
	if( state.value == 1, {
		test = Array.fill( array_scale[ win_scale_select.value ].size, {arg i;
			Synth( \AQI, [\freqmul, array_scale[ win_scale_select.value ][i] ] )
			.map(\freq, fundfreq.index, \amp, fundamp.index, \ampmul, test_ampmul[i].index);
		} );
		aqi_spec.do( { arg spec, i;
			test_ampmul[i].value = ( spec.unmap( win_testdata_box.value ) );
		} );
	}, {
		test.do( { arg synth;
			synth.free;
		});
		test = nil;
	} );
} )
.states_( [["Start Sonification", Color.black, Color.green], ["Stop Sonification", Color.black, Color.red]] );

//----------------
// Testing Layout
var win_testing = GridLayout.rows(
	[
		StaticText().string_("Try it out"),
		win_reference_btn,
		win_test_btn
	], [
		StaticText().string_("Set Data Value"),
		win_testdata_slider,
		win_testdata_box
	]
);

//----------------------
// End Testing section -
//----------------------

//------------------------------
//- Start Data Loading section -
//------------------------------
// File Path, Select File
var win_file_text = TextField().string_("File Path").align_(\right);

var win_file_btn = Button().states_( [["Select File"]] )
.action_({arg state;
	FileDialog({ |paths|
		win_file_text.value = paths[0];
	}, {
		postln("Dialog was cancelled. Try again.");
	});
});

// Select Data colum
var win_datacolum_box = NumberBox().action_( ).value_(0).align_(\right);

var win_datacolum_text = StaticText().string_("No Data Loaded");

// Load Data
var data;

var win_loaddata_btn = Button().states_( [["Load Data"]] )
.action_( {arg state;
	var raw_data;

	// Read Data
	raw_data = CSVFileReader.read( win_file_text.value, true );

	// Remove Header
	win_datacolum_text.string_(raw_data[0][win_datacolum_box.value]);
	raw_data.removeAt(0);

	// Store requiered data
	data = Array.newClear;
	raw_data.do( {arg line, i;
		data = data.add(line[win_datacolum_box.value].asFloat);
	});
} );

// Data Loading Layout
var win_loading = GridLayout.rows(
	[
		win_file_btn,
		[ win_file_text, columns:2 ]
	], [
		StaticText().string_("Select Air Quality Data Column"),
		win_datacolum_box,
		win_datacolum_text
	], [
		[ win_loaddata_btn, columns:3 ]
	]
);
//----------------------------
//- End Data Loading section -
//----------------------------

//--------------------------
//- Start Playback section -
//--------------------------
// Set BPM
var win_bpm_box = NumberBox().align_(\right)
.valueAction_(120);

// Play Button
var win_play_btn = Button().states_( [["Play"]] )
.action_( { arg state

	// Start Reference Synth
	if( win_reference_btn.value == 1 , {
		reference = Synth( \Reference );
		reference.map(\freq, fundfreq.index);
		reference.map(\amp, fundamp.index);
		win_reference_btn.value_( 0 )
	});
});

// Pause Button
var win_pause_btn = Button().states_( [["Pause"]] );

// Stop Button
var win_stop_btn = Button().states_( [["Stop"]] );

// Playback Layout
var win_playback = GridLayout.rows(
	[
		StaticText().string_("Set BPM (Data Points per Minute)"),
		win_bpm_box
	], [
		win_play_btn,
		win_pause_btn,
		win_stop_btn
	]
);

//------------------------
//- End Playback section -
//------------------------

//------------------------
//- Start Window section -
//-----------------------------------
// Vertical aligned settings section
var win_settings = VLayout(
	StaticText().string_("Audio Settings").font_(h1),
	win_settings_audio,
	win_testing,
	StaticText().string_("Load Data").font_(h1),
	win_loading,
	StaticText().string_("Play Data").font_(h1),
	win_playback
);


//--------
// Window
// GUI element
var win = Window.new( "Air Quality Data Sonification" ).front
.layout_( win_settings )
.onClose_( { arg state;
	// free freq and amp bus
	fundfreq.free;
	fundamp.free;

	// free reference synth
	reference.free;

	// free test synths
	test.do( { arg synth;
		synth.free;
	});
	test_ampmul.do( { arg bus;
		bus.free;
	});
} );
//----------------------
//- End Window section -
//----------------------
)