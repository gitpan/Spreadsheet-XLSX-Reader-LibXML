package Spreadsheet::XLSX::Reader::LibXML;
BEGIN {
  $Spreadsheet::XLSX::Reader::LibXML::AUTHORITY = 'cpan:JANDREW';
}
use version 0.77; our $VERSION = qv('v0.34.0');

use 5.010;
use	List::Util 1.33;
use	Moose;
use	MooseX::StrictConstructor;
use	MooseX::HasDefaults::RO;
use	Carp qw( confess );
use	Archive::Zip qw( AZ_OK );
use	XML::LibXML;
use	XML::LibXML::Reader;
use	IO::File;
use Types::Standard qw(
 		InstanceOf			Str       		StrMatch
		Enum				HashRef			ArrayRef
		CodeRef				Int				HasMethods
		Bool
    );
use	MooseX::ShortCut::BuildInstance 1.032 qw( build_instance should_re_use_classes );
use lib	'../../../../lib',;
###LogSD with 'Log::Shiras::LogSpace';
###LogSD use Log::Shiras::Telephone;
###LogSD use Log::Shiras::UnhideDebug;
should_re_use_classes( 1 );
use	Spreadsheet::XLSX::Reader::LibXML::Error;
use	Spreadsheet::XLSX::Reader::LibXML::XMLReader::Styles;
use	Spreadsheet::XLSX::Reader::LibXML::FmtDefault;
use	Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings;
use	Spreadsheet::XLSX::Reader::LibXML::XMLReader::SharedStrings;
use	Spreadsheet::XLSX::Reader::LibXML::XMLReader::Worksheet;
use	Spreadsheet::XLSX::Reader::LibXML::Types qw( XLSXFile ParserType IOFileType );

#########1 Dispatch Tables    3#########4#########5#########6#########7#########8#########9

my	$parser_modules ={
		reader =>{
			build_method => '_build_reader',
			sharedStrings =>{
				superclasses	=> ['Spreadsheet::XLSX::Reader::LibXML::XMLReader::SharedStrings'],
				attributes		=> [qw( error_inst )],
				store			=> '_set_shared_strings_instance',
				package			=> 'SharedStringsInstance',
			},
			styles =>{
				superclasses			=> ['Spreadsheet::XLSX::Reader::LibXML::XMLReader::Styles'],
				attributes				=> [qw( epoch_year error_inst )],
				add_roles_in_sequence	=> [qw( default_format_list format_string_parser )],
				store					=> '_set_styles_instance',
				package					=> 'StylesInstance',
			},
			worksheet =>{
				superclasses	=> ['Spreadsheet::XLSX::Reader::LibXML::XMLReader::Worksheet'],
				#~ store			=> '_set_worksheet_superclass',
			},
		},
	};
my	$xml_parser = XML::LibXML->new();
my	$build_ref	= {
		top_level_workbook =>{
			zip	=> 'xl/workbook.xml',
		},
		workbook_rels =>{
			zip	=> 'xl/_rels/workbook.xml.rels',
		},
		doc_props =>{
			zip	=> 'docProps/core.xml',
		},
		sharedStrings =>{
			zip	=> 'xl/sharedStrings.xml',
		},
		styles =>{
			zip	=> 'xl/styles.xml',
		},
		calcChain =>{
			zip	=> 'xl/calcChain.xml',
		},
	};

#########1 Public Attributes  3#########4#########5#########6#########7#########8#########9

has	error_inst =>(
		isa			=> 	HasMethods[qw(
							error set_error clear_error set_warnings if_warn
						) ],
		clearer		=> '_clear_error_inst',
		reader		=> 'get_error_inst',
		required	=> 1,
		handles =>[ qw(
			error set_error clear_error set_warnings if_warn
		) ],
		default => sub{ Spreadsheet::XLSX::Reader::LibXML::Error->new( should_warn => 0 ) },
	);

has file_name =>(
		isa			=> XLSXFile,
		writer		=> 'set_file_name',
		clearer		=> '_clear_file_name',
		predicate	=> 'has_file_name',
		trigger		=> \&_build_workbook,
	);

has file_handle =>(
		isa			=> IOFileType,
		writer		=> 'set_file_handle',
		clearer		=> '_clear_file_handle',
		predicate	=> 'has_file_handle',
		coerce		=> 1,
		trigger		=> \&_build_workbook,
	);
	
has file_creator =>(
		isa		=> Str,
		reader	=> 'creator',
		writer	=> '_set_creator',
		clearer	=> '_clear_creator',
	);
	
has file_modified_by =>(
		isa		=> Str,
		reader	=> 'modified_by',
		writer	=> '_set_modified_by',
		clearer	=> '_clear_modified_by',
	);
	
has file_date_created =>(
		isa		=> StrMatch[qr/^\d{4}\-\d{2}\-\d{2}/],
		reader	=> 'date_created',
		writer	=> '_set_date_created',
		clearer	=> '_clear_date_created',
	);
	
has file_date_modified =>(
		isa		=> StrMatch[qr/^\d{4}\-\d{2}\-\d{2}/],
		reader	=> 'date_modified',
		writer	=> '_set_date_modified',
		clearer	=> '_clear_date_modified',
	);

has sheet_parser =>(
		isa		=> ParserType,
		writer	=> 'set_parser_type',
		reader	=> 'get_parser_type',
		default	=> 'reader',
		coerce	=> 1,
	);

has count_from_zero =>(
		isa		=> Bool,
		reader	=> 'counting_from_zero',
		writer	=> 'set_count_from_zero',
		default	=> 1,
	);
	
has file_boundary_flags =>(
		isa			=> Bool,
		reader		=> 'boundary_flag_setting',
		writer		=> 'change_boundary_flag',
		default		=> 1,
		required	=> 1,
	);

has empty_is_end =>(
		isa		=> Bool,
		writer	=> 'set_empty_is_end',
		reader	=> 'is_empty_the_end',
		default	=> 0,
	);

has from_the_edge =>(
		isa		=> Bool,
		reader	=> '_starts_at_the_edge',
		writer	=> 'set_from_the_edge',
		default	=> 1,
	);

has default_format_list =>(
		isa		=> Str,
		writer	=> 'set_default_format_list',
		reader	=> 'get_default_format_list',
		default	=> 'Spreadsheet::XLSX::Reader::LibXML::FmtDefault',
	);

has format_string_parser =>(
		isa		=> Str,
		writer	=> 'set_format_string_parser',
		reader	=> 'get_format_string_parser',
		default	=> 'Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings',
	);

has group_return_type =>(
		isa		=> Enum[qw( unformatted value instance )],
		reader	=> 'get_group_return_type',
		writer	=> 'set_group_return_type',
		default	=> 'instance',
	);

has empty_return_type =>(
		isa		=> Enum[qw( empty_string undef_string )],
		reader	=> 'get_empty_return_type',
		writer	=> 'set_empty_return_type',
		default	=> 'empty_string',
	);

#########1 Public Methods     3#########4#########5#########6#########7#########8#########9

sub parse{

    my ( $self, $file, $formatter ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> $self->get_log_space .  '::Workbook::parse', );
	###LogSD		$phone->talk( level => 'info', message =>[
	###LogSD			"Arrived at parse for:", $file,
	###LogSD			(($formatter) ? "with formatter: $formatter" : '') ] );
	$self->set_format_string_parser( $formatter ) if $formatter;
	if( IOFileType->check( $file ) ){
		###LogSD	$phone->talk( level => 'info', message =>[ 'passed a file handle:', $file, ] );
		eval '$self->set_file_handle( $file )';
	}else{
		###LogSD	$phone->talk( level => 'info', message =>[ 'passed a file name: ' . $file, ] );
		eval '$self->set_file_name( $file )';
	}
	if( $@ ){
		my $error_message = $@;
		###LogSD	$phone->talk( level => 'info', message =>[ 'saving error:', $error_message, ] );
		$self->set_error( $error_message );
		return undef;
	}else{
		return $self;
	}
}

sub worksheets{

    my ( $self, ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> $self->get_log_space .  '::Workbook::worksheets', );
	###LogSD		$phone->talk( level => 'info', message =>[
	###LogSD			'Attempting to build all worksheets: ', $self->get_worksheet_names ] );
	my	@worksheet_array;
	while( my $worksheet_object = $self->worksheet ){
		###LogSD	$phone->talk( level => 'info', message =>[
		###LogSD		'Built worksheet: ' .  $worksheet_object->get_name ] );
		push @worksheet_array, $worksheet_object;#$self->worksheet( $worksheet_name );
	}
	###LogSD	$phone->talk( level => 'trace', message =>[
	###LogSD		'sending worksheet array: ',@worksheet_array ] );
	return @worksheet_array;
}

sub worksheet{

    my ( $self, $worksheet_name ) = @_;
	my ( $next_position );
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> $self->get_log_space .  '::Workbook::worksheet', );
	###LogSD		$phone->talk( level => 'info', message =>[
	###LogSD			"Arrived at (build a) worksheet with: ", $worksheet_name ] );
	
	# Check for a file and an available parser type
	confess "No file loaded yet" if !$self->has_file_name and !$self->has_file_handle;
	my ( $translation_method, $parser_type );
	if( exists $parser_modules->{ $self->get_parser_type } ){
		$translation_method	= $parser_modules->{ $self->get_parser_type }->{build_method};
		$parser_type		= $parser_modules->{ $self->get_parser_type }->{worksheet};
	}else{
		confess 'This package still under development - parser type |' . $self->get_parser_type . '| not yet supported - try the "reader" parser';
		return undef;
	}
	###LogSD		$phone->talk( level => 'info', message =>[
	###LogSD			"Using translation: $translation_method", "With parser: ", $parser_type, ] );
	
	# Handle an implied 'next sheet'
	if( !$worksheet_name ){
		my $worksheet_position = $self->_get_current_worksheet_position;
		###LogSD	$phone->talk( level => 'info', message =>[
		###LogSD		"No worksheet name passed", 
		###LogSD		((defined $worksheet_position) ? "Starting after position: $worksheet_position" : '')] );
		$next_position = ( !$self->in_the_list ) ? 0 : ($self->_get_current_worksheet_position + 1);
		###LogSD	$phone->talk( level => 'info', message =>[
		###LogSD		"No worksheet name passed", "Attempting position: $next_position" ] );
		if( $next_position >= $self->number_of_sheets ){
			###LogSD	$phone->talk( level => 'info', message =>[
			###LogSD		"Reached the end of the worksheet list" ] );
			return undef;
		}
		$worksheet_name = $self->worksheet_name( $next_position );
		###LogSD	$phone->talk( level => 'info', message =>[
		###LogSD		"Now attempting to build the worksheet named: $worksheet_name", ] );
	}
	
	# build the worksheet
	my	$worksheet_info = $self->_get_worksheet_info( $worksheet_name );
	###LogSD	$phone->talk( level => 'info', message =>[
	###LogSD		'Returned worksheet info:', $worksheet_info, ] );
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"Attempting to build the worsheet: $worksheet_name\.xml",
	###LogSD		"With translation method: $translation_method" ], );
	my %args = $self->$translation_method( $worksheet_info, $self->_get_zip_file_handle );
	if( !$args{xml_reader} and !$args{dom} ){
		$self->set_error( "Unable to load XML::LibXML with the element: $worksheet_name" );
		return undef;
	}
	
	confess "No worksheet info for: $worksheet_name" if !exists $worksheet_info->{sheet_position};
	$args{superclasses}			= $parser_type->{superclasses};
	$args{sheet_name}			= $worksheet_name;
	$args{workbook_instance}	= $self;
	$args{error_inst}			= $self->get_error_inst;
	$args{package}				= 'WorksheetInstance';
	###LogSD $args{log_space} = $self->get_log_space . "::Worksheet";
	###LogSD	$phone->talk( level => 'trace', message =>[
	###LogSD		'Built an xml object with final worksheet build info:', %args, ] );
	my	$worksheet = build_instance( %args );
	if( $worksheet ){
		###LogSD	$phone->talk( level => 'info', message =>[
		###LogSD		"Successfully loaded: $worksheet_name",] );
		$self->_set_current_worksheet_position( $worksheet->position );
		return $worksheet;
	}else{
		$self->set_error( "Failed to build the object for worksheet: $worksheet_name" );
		return undef;
	}
}

#########1 Private Attributes 3#########4#########5#########6#########7#########8#########9

has _epoch_year =>(
		isa		=> Enum[qw( 1900 1904 )],
		writer	=> '_set_epoch_year',
		reader	=> 'get_epoch_year',
		default	=> 1900,
	);
	
has _shared_strings_instance =>(
		isa			=> HasMethods[ 'get_shared_string_position' ],
		predicate	=> '_has_shared_strings_file',
		writer		=> '_set_shared_strings_instance',
		reader		=> '_get_shared_strings_instance',
		clearer		=> '_clear_shared_strings',
		handles		=>{
			'get_shared_string_position' => 'get_shared_string_position',
			_demolish_shared_strings => 'DEMOLISH',
		},
	);
	
has _styles_instance =>(
		isa			=> HasMethods[qw( get_format_position )],
		writer		=> '_set_styles_instance',
		reader		=> '_get_styles_instance',
		clearer		=> '_clear_styles',
		predicate	=> '_has_styles_file',
		handles		=>{
			get_format_position	=> 'get_format_position',
			set_defined_excel_format_list => 'set_defined_excel_format_list',
			change_output_encoding => 'change_output_encoding',
			get_date_behavior => 'get_date_behavior',
			set_date_behavior => 'set_date_behavior',
			parse_excel_format_string => 'parse_excel_format_string',
			_demolish_styles => 'DEMOLISH',
		},
	);

has _calc_chain_instance =>(
	isa	=> 	HasMethods[qw( get_calc_chain_position )],
	writer	=>'_set_calc_chain_instance',
	reader	=>'_get_calc_chain_instance',
	clearer	=> '_clear_calc_chain',
	predicate => '_has_calc_chain_file',
	handles =>{
		_demolish_calc_chain => 'DEMOLISH',
	},
);

has _worksheet_list =>(
		isa		=> ArrayRef,
		traits	=> ['Array'],
		writer	=> '_set_worksheet_list',
		clearer	=> '_clear_worksheet_list',
		reader	=> 'get_worksheet_names',
		handles	=>{
			worksheet_name => 'get',
		},
		default	=> sub{ [] },
	);

has _worksheet_lookup =>(
		isa		=> HashRef,
		traits	=> ['Hash'],
		writer	=> '_set_worksheet_lookup',
		clearer	=> '_clear_worksheet_lookup',
		reader	=> '_get_worksheet_lookup',
		handles	=>{
			_get_worksheet_info => 'get',
			number_of_sheets	=> 'count',
		},
		default	=> sub{ {} },
	);

has _current_worksheet_position =>(
		isa			=> Int,
		writer		=> '_set_current_worksheet_position',
		reader		=> '_get_current_worksheet_position',
		clearer		=> 'start_at_the_beginning',
		predicate	=> 'in_the_list',
	);
	
has _file_type =>(
		isa		=> Enum[qw( zip xml )],
		clearer	=> '_clear_file_type',
		writer	=> '_set_file_type',
		reader	=> '_get_file_type',
	);
	
has _zip_file_handle =>(
		isa => InstanceOf[ 'Archive::Zip' ],
		clearer	=> '_clear_zip_file_handle',
		writer	=> '_set_zip_file_handle',
		reader	=> '_get_zip_file_handle',
	);

#########1 Private Methods    3#########4#########5#########6#########7#########8#########9

sub _build_workbook{

    my ( $self, $file ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> $self->get_log_space .  '::Workbook::_build_file', );
	###LogSD		$phone->talk( level => 'info', message =>[
	###LogSD			'Arrived at _build_file for: ', $file ] );
	$self->_clear_shared_strings;
	$self->_clear_calc_chain;
	$self->_clear_styles;
	$self->_clear_worksheet_list;
	$self->_clear_worksheet_lookup;
	$self->_clear_creator;
	$self->_clear_modified_by;
	$self->_clear_date_created;
	$self->_clear_date_modified;
	$self->clear_error;
	$self->start_at_the_beginning;
	$self->_clear_file_type;
	
	# Ensure we have a file handle
	my $file_handle;
	eval '$file_handle = IOFileType->assert_coerce( $file )';
	###LogSD	$phone->talk( level	=> 'trace', message =>[
	###LogSD		"Passed the file type coercion" ] );
	if( $@ ){
		###LogSD	$phone->talk( level	=> 'warn', message =>[
		###LogSD		"Unable to create a valid file instance with: $file" ] );
		$self->_clear_file_handle;
		$self->_clear_file_name;
		$self->set_error( "Unable to create a valid file instance with: $file" );
		return undef;
	}
	###LogSD	$phone->talk( level	=> 'trace', message =>[
	###LogSD		"Current file handle: $file_handle" ] );
	
    # Read the XLSX zip file and catch any errors (other zip file sanity tests go here)
	my $workbook_file = Archive::Zip->new();
    if(	$workbook_file->readFromFileHandle($file_handle) != AZ_OK ){
		###LogSD	$phone->talk( level	=> 'warn', message =>[
		###LogSD		"Failed to open a zip file" ] );
		$self->_clear_file_handle;
		$self->_clear_file_name;
		$self->_set_file_type( 'xml' );#  Build from this when adding all-in-one single file Excel Workbooks!!!!
		confess "|$file| won't open as a zip file";
	}else{
		###LogSD	$phone->talk( level	=> 'debug', message =>[
		###LogSD		"Certified this as a zip file" ] );
		$self->_set_file_type( 'zip' );
	}
	###LogSD	$phone->talk( level	=> 'debug', message =>[
	###LogSD		'Zip file test passed with: ' . $self->_get_file_type ] );
	
	# Extract the workbook top level info
	my %answer = $self->_build_dom( $build_ref->{top_level_workbook}, $workbook_file );
	###LogSD	$phone->talk( level	=> 'debug', message =>[ "DOM built for method: _load_top_level_workbook" ] );
	my ( $rel_lookup, $id_lookup ) = $self->_load_top_level_workbook( $answer{dom} );
	return undef if !$rel_lookup;
	###LogSD	$phone->talk( level => 'debug', message =>[ 'Rel lookup:', $rel_lookup, 'ID lookukp:', $id_lookup	] );
	
	# Load the workbook rels info
	%answer = $self->_build_dom( $build_ref->{workbook_rels}, $workbook_file );
	###LogSD	$phone->talk( level	=> 'debug', message =>[ "DOM built for method: _load_workbook_rels" ] );
	my ( $pivot_lookup ) = $self->_load_workbook_rels( $rel_lookup, $answer{dom} );
	return undef if !$pivot_lookup;
	###LogSD	$phone->talk( level => 'debug', message =>[ 'pivot lookup:', $pivot_lookup,	] );
	
	# Load the docProps info
	%answer = $self->_build_dom( $build_ref->{doc_props}, $workbook_file );
	###LogSD	$phone->talk( level	=> 'debug', message =>[ "DOM built for method: _load_doc_props" ] );
	$self->_load_doc_props( $answer{dom} );
	###LogSD	$phone->talk( level => 'debug', message =>[ 'docProps loaded', ] );
	
	# Build the instances for all the shared files (data for sheets shared across worksheets)
	if( exists $parser_modules->{ $self->get_parser_type } ){
		my	$result = 	$self->_set_shared_worksheet_files(
							$parser_modules->{ $self->get_parser_type },
							$workbook_file,
						);
		return undef if !$result;
		$self->_set_zip_file_handle( $workbook_file );
	}else{
		confess 'This package still under development - parser type |' . $self->get_parser_type . '| not yet supported - try the "reader" parser';
		return undef;
	}
	return $self;
}

sub _build_dom{
	my( $self, $build_target, $workbook_file ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> $self->get_log_space .  '::Workbook::_build_dom', );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			'Building DOM object for the target:', $build_target,
	###LogSD			"With file:", $workbook_file	] );
	my ( $dom, $encoding );
	if( $self->_get_file_type eq 'zip' ){
		###LogSD		$phone->talk( level => 'debug', message => [
		###LogSD			"Working on a zip file targeting: $build_target->{zip}",] );
		my $zip_workbook = $workbook_file->memberNamed( $build_target->{zip} );
		delete $build_target->{zip};
		###LogSD	$phone->talk( level => 'debug', message =>[ 'zip member: ' . $zip_workbook	] );
		my	$workbook_fh = IO::File->new_tmpfile;
			$workbook_fh->binmode();
		$zip_workbook->extractToFileHandle( $workbook_fh );
		$workbook_fh->seek( 0, 0 );
		$dom = $xml_parser->load_xml( { IO => $workbook_fh } );
	}else{
		confess "I don't know how to handle file type: " . $self->_get_file_type;
	}
	my %return_args = ( dom => $dom, %$build_target );
	###LogSD	$phone->talk( level => 'debug', message =>[ "Returning: ", %return_args ] );
	return %return_args;
}

sub _build_reader{
	my( $self, $build_target, $workbook_file ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> $self->get_log_space .  '::Workbook::_build_reader', );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			'Building Reader object for the target:', $build_target,
	###LogSD			"With file:", $workbook_file	] );
	my ( $workbook_fh, $xml_reader, $encoding );
	if( $self->_get_file_type eq 'zip' ){
		###LogSD		$phone->talk( level => 'debug', message => [
		###LogSD			"Working on a zip file targeting: $build_target->{zip}",] );
		my $zip_member = $workbook_file->memberNamed( $build_target->{zip} );
		delete $build_target->{zip};
		###LogSD	$phone->talk( level => 'debug', message =>[ 'zip member:', $zip_member	] );
		$workbook_fh = IO::File->new_tmpfile;
		$workbook_fh->binmode();
		$zip_member->extractToFileHandle( $workbook_fh );
		$workbook_fh->seek( 0, 0 );
		$xml_reader = XML::LibXML::Reader->new( IO => $workbook_fh );
		$xml_reader->read;
	}else{
		confess "I don't know how to handle file type: " . $self->_get_file_type;
	}
	my %return_args = ( xml_reader => $xml_reader, file_handle => $workbook_fh, %$build_target );
	###LogSD	$phone->talk( level => 'debug', message =>[ "Returning: ", %return_args ] );
	return %return_args;
}

sub _load_top_level_workbook{
	my( $self, $dom ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> $self->get_log_space .  '::Workbook::_load_workbook_file', );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			"Building the top level data for the workbook", ] );
	my ( $list, $sheet_ref, $rel_lookup, $id_lookup );
	my	$position = 0;
	my ( $setting_node ) = $dom->getElementsByTagName( 'workbookPr' );
	$self->_set_epoch_year( 1904 ) if $setting_node->getAttribute( 'date1904' );
	for my $sheet ( $dom->getElementsByTagName( 'sheet' ) ){
		my	$sheet_name = $sheet->getAttribute( 'name' );
		push @$list, $sheet_name;
		@{$sheet_ref->{$sheet_name}}{ 'sheet_id', 'sheet_rel_id', 'sheet_position' } = (
				$sheet->getAttribute( 'sheetId' ),
				$sheet->getAttribute( 'r:id' ),
				$position++,
		);
		$rel_lookup->{$sheet->getAttribute( 'r:id' )} = $sheet_name;
		$id_lookup->{$sheet->getAttribute( 'sheetId' )} = $sheet_name;
	}
	for my $sheet ( $dom->getElementsByTagName( 'pivotCache' ) ){
		my	$sheet_id = $sheet->getAttribute( 'cacheId' );
		my	$rel_id = $sheet->getAttribute( 'r:id' );
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		"Sheet ID: $sheet_id", "Rel ID: $rel_id", ] );
		$rel_lookup->{$rel_id} = $sheet_id;
		$id_lookup->{$sheet_id} = $rel_id;
	}
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"Sheet list: ", $list,
	###LogSD		"Worksheet lookup:", $sheet_ref,
	###LogSD		"rel lookup:", $rel_lookup,
	###LogSD		"id lookup:", $id_lookup,		] );
	$dom = undef;
	if( !$list ){
		$self->set_error( "No worksheets identified in this workbook" );
		return undef;
	}
	$self->_set_worksheet_list( $list );
	$self->_set_worksheet_lookup( $sheet_ref );
	return( $rel_lookup, $id_lookup );
}

sub _load_workbook_rels{
	my( $self, $rel_lookup, $dom ) = @_;
	my ( $pivot_lookup, );
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> $self->get_log_space .  '::Workbook::_load_workbook_rels', );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			"Adding the rels file data for the workbook with:", $rel_lookup ] );
	my	$sheet_ref = $self->_get_worksheet_lookup;
	my	$found_member_names = 0;
	for my $sheet ( $dom->getElementsByTagName( 'Relationship' ) ){
		my	$rel_ID = $sheet->getAttribute( 'Id' );
		if( exists $rel_lookup->{$rel_ID} ){
			my	$target = 'xl/';
				$target .= $sheet->getAttribute( 'Target' );
			###LogSD	$phone->talk( level => 'debug', message => [
			###LogSD		"Building relationship for: $rel_ID", "With target: $target" ] );
			$target =~ s/\\/\//g;
			if( $target =~ /worksheets/ ){
				$sheet_ref->{$rel_lookup->{$rel_ID}}->{zip} = $target;
				$found_member_names = 1;
			}else{
				$pivot_lookup->{$rel_ID} = $target;
			}
		}
	}
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"Worksheet lookup:", $sheet_ref,
	###LogSD		"Pivot lookup:", $pivot_lookup	] );
	if( !$found_member_names ){
		$self->set_error( "Couldn't find any zip member (file) names for the sheets" );
		return undef;
	}
	$self->_set_worksheet_lookup( $sheet_ref );
	return $pivot_lookup;
}

sub _load_doc_props{
	my( $self, $dom ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> $self->get_log_space .  '::Workbook::_load_doc_props', );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			"Collecting data from the doc props file", ] );
	$self->_set_creator( ($dom->getElementsByTagName( 'dc:creator' ))[0]->textContent() );
	$self->_set_modified_by( ($dom->getElementsByTagName( 'cp:lastModifiedBy' ))[0]->textContent() );
	$self->_set_date_created(
			($dom->getElementsByTagName( 'dcterms:created' ))[0]->textContent()
	);
	$self->_set_date_modified(
			($dom->getElementsByTagName( 'dcterms:modified' ))[0]->textContent()
	);
	###LogSD	$phone->talk( level => 'trace', message => [ "Current object:", $self ] );
}

sub _set_shared_worksheet_files{
	my( $self, $object_ref, $zip_workbook ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> $self->get_log_space .  '::Workbook::_set_shared_worksheet_files', );
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"Building the shared worksheet files with the lookup ref:", $object_ref, ] );
	my $translation_method = $object_ref->{build_method};
	for my $file ( keys %$object_ref ){
		next if $file eq 'build_method' or $file eq 'worksheet';
			###LogSD	$phone->talk( level => 'debug', message => [
			###LogSD		"checking the file class: $file",], );
		if( $file eq 'worksheet' ){
			###LogSD	$phone->talk( level => 'debug', message => [
			###LogSD		"Storing the worksheet superclass: ", $object_ref->{worksheet}->{superclasses}], );
			my $method = $object_ref->{$file}->{store};
			$self->$method( $object_ref->{$file}->{superclasses} );
		}else{
			###LogSD	$phone->talk( level => 'debug', message => [
			###LogSD		"Attempting to load the file: ${file}\.xml",
			###LogSD		"With translation method: $translation_method" ], );
			my %args = $self->$translation_method( $build_ref->{$file}, $zip_workbook );
			if( !$args{xml_reader} and !$args{dom} ){
				$self->set_error( "Unable to load XML::LibXML with the element: $file" );
				next;
			}
			###LogSD	$phone->talk( level => 'debug', message =>[ "Built an xml_object", ], );
			$args{package} = $object_ref->{$file}->{package} if exists $object_ref->{$file}->{package};
			$args{superclasses} = $object_ref->{$file}->{superclasses} if exists $object_ref->{$file}->{superclasses};
			for my $attribute ( @{$object_ref->{$file}->{attributes}} ){
				###LogSD	$phone->talk( level => 'debug', message => [
				###LogSD		"Loading attribute: $attribute", ], );
				my $method = 'get_' . $attribute;
				$args{$attribute} = $self->$method;
			}
			my $role_ref;
			for my $role ( @{$object_ref->{$file}->{add_roles_in_sequence}} ){
				###LogSD	$phone->talk( level => 'debug', message => [
				###LogSD		"collecting the role for: $role", ], );
				my $method = 'get_' . $role;
				push @$role_ref, $self->$method;
			}
			$args{add_roles_in_sequence} = $role_ref if $role_ref;
			###LogSD	$args{log_space} = $self->get_log_space . "::$args{package}";
			my $method = $object_ref->{$file}->{store};
			###LogSD	$phone->talk( level => 'debug', message =>[
			###LogSD		"Final args for building the instance:", %args,
			###LogSD		"Loading -$method- with build_instance( 'args' )"	], );
			my $object = build_instance( %args );
			###LogSD	$phone->talk( level => 'debug', message =>[
			###LogSD		"Finished building instance for: $file",
			###LogSD		"Loading to the worbook with method: $method", # $object	
			###LogSD		], );
			$self->$method( $object );
			###LogSD	$phone->talk( level => 'debug', message =>[
			###LogSD		"Finished building and installing: $file", ], );
		}
		###LogSD	$phone->talk( level => 'debug', message => [
		###LogSD		"Finished the attempt at: $file"	], );
	}
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"All shared files that can be built are built!"	], );
	return 1;
}

sub DEMOLISH{
	my ( $self ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> $self->get_log_space .  '::Workbook::DEMOLISH', );
	if( $self->_has_calc_chain_file ){
		#~ print "closing calcChain.xml\n";
		###LogSD	$phone->talk( level => 'debug', message => [
		###LogSD			"Clearing the calcChain.xml file" ] );
		$self->_demolish_calc_chain;
	}
	if( $self->_has_shared_strings_file ){
		my $instance = $self->_get_shared_strings_instance;
		#~ print "closing sharedStrings.xml\n" . Dumper( $instance );
		###LogSD	$phone->talk( level => 'debug', message => [
		###LogSD			"Clearing the sharedStrings.xml file" ] );
		if( $instance ){
			$self->_demolish_shared_strings;
		}else{
			$self->_clear_shared_strings;
			$instance = undef;
		}
	}
	
	if( $self->_has_styles_file ){
		my $instance = $self->_get_styles_instance;
		#~ print "closing styles.xml\n" . Dumper( $instance );
		###LogSD	$phone->talk( level => 'debug', message => [
		###LogSD			"Clearing the styles.xml file" ] );
		if( $instance ){
			$self->_demolish_styles;
		}else{
			$self->_clear_shared_strings;
			$instance = undef;
		}
	}
	
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"Clearing the Zip file handle" ] );
	$self->_clear_zip_file_handle;
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"Clearing the top level file handle" ] );
	$self->_clear_file_handle;
}

#########1 Phinish            3#########4#########5#########6#########7#########8#########9

no Moose;
__PACKAGE__->meta->make_immutable;
	
1;

#########1 Documentation      3#########4#########5#########6#########7#########8#########9
__END__

=head1 NAME

Spreadsheet::XLSX::Reader::LibXML - Read xlsx spreadsheet files with LibXML

=head1 SYNOPSIS

The following uses the 'TestBook.xlsx' file found in the t/test_files/ folder

	#!/usr/bin/env perl
	use strict;
	use warnings;
	use Spreadsheet::XLSX::Reader::LibXML;

	my $parser   = Spreadsheet::XLSX::Reader::LibXML->new();
	my $workbook = $parser->parse( 'TestBook.xlsx' );

	if ( !defined $workbook ) {
		die $parser->error(), "\n";
	}

	for my $worksheet ( $workbook->worksheets() ) {

		my ( $row_min, $row_max ) = $worksheet->row_range();
		my ( $col_min, $col_max ) = $worksheet->col_range();

		for my $row ( $row_min .. $row_max ) {
			for my $col ( $col_min .. $col_max ) {

				my $cell = $worksheet->get_cell( $row, $col );
				next unless $cell;

				print "Row, Col    = ($row, $col)\n";
				print "Value       = ", $cell->value(),       "\n";
				print "Unformatted = ", $cell->unformatted(), "\n";
				print "\n";
			}
		}
		last;# In order not to read all sheets
	}

	###########################
	# SYNOPSIS Screen Output
	# 01: Row, Col    = (0, 0)
	# 02: Value       = Category
	# 03: Unformatted = Category
	# 04: 
	# 05: Row, Col    = (0, 1)
	# 06: Value       = Total
	# 07: Unformatted = Total
	# 08: 
	# 09: Row, Col    = (0, 2)
	# 10: Value       = Date
	# 11: Unformatted = Date
	# 12: 
	# 13: Row, Col    = (1, 0)
	# 14: Value       = Red
	# 16: Unformatted = Red
	# 17: 
	# 18: Row, Col    = (1, 1)
	# 19: Value       = 5
	# 20: Unformatted = 5
	# 21: 
	# 22: Row, Col    = (1, 2)
	# 23: Value       = 2017-2-14 #(shows as 2/14/2017 in the sheet)
	# 24: Unformatted = 41318
	# 25: 
	# More intermediate rows ... 
	# 82: 
	# 83: Row, Col    = (6, 2)
	# 84: Value       = 2016-2-6 #(shows as 2/6/2016 in the sheet)
	# 85: Unformatted = 40944
	###########################

=head1 DESCRIPTION

This is another module for parsing Excel 2007+ workbooks.  The goals of this package are 
three fold.  First, as close as possible produce the same output as is visible in an 
excel spreadsheet with exposure to underlying settings from Excel.  Second, adhere as 
close as is reasonable to the L<Spreadsheet::ParseExcel> API (where it doesn't conflict 
with the first objective) so that less work would be needed to integrate ParseExcel and 
this package.  Third, to provide an XLSX sheet parser that is built on L<XML::LibXML>.  
The other two primary options for XLSX parsing on CPAN use either a one-off XML parser 
(L<Spreadsheet::XLSX>) or L<XML::Twig> (L<Spreadsheet::ParseXLSX>).  In general if 
either of them already work for you without issue then there is no reason to change to 
this package.  I personally found some bugs and functionality boundaries in both that I 
wanted to improve and by the time I had educated myself enough to make improvement 
suggestions including root causing the bugs to either the XML parser or the reader logic 
I had written this.

In the process of learning and building I also wrote some additional features for 
this parser that are not found in the L<Spreadsheet::ParseExcel> package.  For instance 
in the L<SYNOPSIS|/SYNOPSIS> the '$parser' and the '$workbook' are actually the same class.  
You could combine both steps by calling ->new with the 'file_name' (or 'file_handle') 
attribute called out.  Afterward it is still possible to call ->error on the instance.  
The test in that case for load success would be $instance->has_file_name(handle) Another 
improvement (from my perspective) is date handling.  This package allows for a simple 
pluggable custom output format that is very flexible as well as handling dates older than 
1-January-1900.  I leveraged coercions from L<Type::Tiny|Type::Tiny::Manual> to do this 
but anything that follows that general format will work here.  Additionally, this is a 
L<Moose> based package.  As such it is designed to be (fairly) extensible by writing roles 
and adding them to this package rather than requiring that you extend the package to some 
new branch.  Read the full documentation for all opportunities!

In the realm of extensibility, L<XML::LibXML> has multiple ways to read an XML file but this 
release only has an L<XML::LibXML::Reader> parser option.  Future iterations could include a 
DOM parser option.  Additionally this package does not (yet) provide the same access to the 
formatting elements provided in L<Spreadsheet::ParseExcel>.  That is on the longish and 
incomplete TODO list.

The package operates on the workbook with three primary tiers of classes.  All other classes 
in this package are for architectual extensibility.

=over

---> Workbook level (This class)

=over

---> L<Worksheet level|Spreadsheet::XLSX::Reader::LibXML::Worksheet>

=over

---> L<Cell level|Spreadsheet::XLSX::Reader::LibXML::Cell> - 
L<optional|/group_return_type>

=back

=back

=back

=head2 Warnings

B<1.> Archive-Zip versions greater than 1.30 appear to be broken.  This package requires Archive::Zip so 
I reccomend Archive-Zip-1.30.

B<2.> Earlier versions of this package would extract the .xlsx file to a temp directory and then release 
the file lock on the original file while still retaining the information for acess by the parser.  In order 
to resolve some some temp dir cleanup issues this package no longer releases the lock on the file during 
reading.  (It will release the file lock and clean up any temp directories when the class is closed)

=head2 Primary Methods

These are the primary ways to use this class.  They can be used to open an .xlsx 
workbook.  They are also ways to investigate information at the workbook level.  For 
information on how to retrieve data from the worksheets see the 
L<Worksheet|Spreadsheet::XLSX::Reader::LibXML::Worksheet> and L<Cell|Spreadsheet::XLSX::Reader::LibXML::Cell> 
documentation.  For additional workbook options see the L<Attributes|/Attributes> section.  The 
attributes section also documents all the methods used to adjust the attributes of this class.

=head3 new( %attributes )

=over

B<Definition:> This is the way to instantiate an instance of this class.  It can accept 
settings for all, some, or none of the L<Attributes|/Attributes>.  If the instance is started 
with no arguments then a L<method|/set_file_name> is needed to open the 
xlsx file.

B<Accepts:> the L<attributes|/Attributes>

B<Returns:> An instance of this class

=back

=head3 parse( $file_name|$file_handle, $formatter )

=over

B<Definition:> This is a convenience method to match L<Spreadsheet::ParseExcel/parse($filename, $formatter)>.  
It only works if the L<file_name|/file_name> or L<file_handle|/file_handle> attribute was not 
set with ->new.  It is one way to set the 'file_name' or 'file_handle' attribute [and the 
L<default_format_list|/default_format_list> attribute].  I<You cannot pass both a file name 
and a file handle simultaneously to this method.>

B<Accepts:>

	$file = a valid xlsx file [or a valid xlsx file handle] (required)
	[$formatter] = see the default_format_list attribute for valid options (optional)

B<Returns:> itself when passing with the xlsx file loaded to the workbook level or 
undef for failure.

=back

=head3 worksheets

=over

B<Definition:> This method will return an array (I<not an array reference>) 
containing a list of references to all worksheets in the workbook.  This is not 
a reccomended method.  It is provided for compatibility to Spreadsheet::ParseExcel.  
For alternatives see the L<get_worksheet_names|/get_worksheet_names> method and the
L<worksheet|/worksheet( $name )> methods.

B<Accepts:> nothing

B<Returns:> an array ref of  L<Worksheet|Spreadsheet::XLSX::Reader::LibXML::Worksheet> 
objects for all worksheets in the workbook.

=back

=head3 worksheet( $name )

=over

B<Definition:> This method will return an  object to read values in the worksheet.  
If no value is passed to $name then the 'next' worksheet in physical order is 
returned. I<'next' will NOT wrap>

B<Accepts:> the $name string representing the name of the worksheet object you 
want to open.  This name is the word visible on the tab when opening the spreadsheet 
in Excel. (not the underlying zip member file name - which can be different)

B<Returns:> a L<Worksheet|Spreadsheet::XLSX::Reader::LibXML::Worksheet> object with the 
ability to read the worksheet of that name.  Or in 'next' mode it returns undef if 
past the last sheet

B<Example:> using the implied 'next' worksheet;

	while( my $worksheet = $workbook->worksheet ){
		print "Reading: " . $worksheet->name . "\n";
		# get the data needed from this worksheet
	}

=back

=head3 in_the_list

=over

B<Definition:> This is a predicate method that indicates if the 'next' 
L<worksheet|/worksheet( $name )> function has been implemented at least once.

B<Accepts:>nothing

B<Returns:> true = 1, false = 0
once

=back

=head3 start_at_the_beginning

=over

B<Definition:> This restarts the 'next' worksheet at the first worksheet.  This 
method is only useful in the context of the L<worksheet|/worksheet( $name )> 
function.

B<Accepts:> nothing

B<Returns:> nothing

=back

=head3 number_of_sheets

=over

B<Definition:> This method returns the count of worksheets in the workbook

B<Accepts:>nothing

B<Returns:> an integer

=back

=head3 get_worksheet_names

=over

B<Definition:> This method returns an array ref of all the worksheet names in the 
workbook.

B<Accepts:> nothing

B<Returns:> an array ref

B<Example:> Another way to parse a workbook without building all the sheets at 
once is;

	for $sheet_name ( @{$workbook->worksheet_names} ){
		my $worksheet = $workbook->worksheet( $sheet_name );
		# Read the worksheet here
	}

=back

=head3 worksheet_name( $Int )

=over

B<Definition:> This method returns the worksheet name for a given physical position 
in the worksheet from left to right. It counts from zero even if the workbook is in 
'count_from_one' mode.

B<Accepts:> integers

B<Returns:> the worksheet name

B<Example:> To return only worksheet positions 2 through 4

	for $x (2..4){
		my $worksheet = $workbook->worksheet( $workbook->worksheet_name( $x ) );
		# Read the worksheet here
	}

=back

=head3 error

=over

B<Definition:> This returns the most recent error message logged by the package.  
This method is mostly relevant when an unexpected result is returned by some other 
method.

B<Accepts:>nothing

B<Returns:> an error string.

=back

=head3 get_epoch_year

=over

B<Definition:> This returns the epoch year defined by the workbook.

B<Accepts:> nothing

B<Returns:> 1900 = Windows Excel or 1904 = Apple Excel

=back

=head3 parse_excel_format_string( $format_string )

=over

B<Definition:> This returns a L<Type::Tiny> object with built-in chained coercions 
to turn Excel Julian Dates and general date strings into target-formatted date strings.

B<Accepts:> a custom $format_string complying with L<Excel definitions 
|https://support.office.com/en-us/article/Create-or-delete-a-custom-number-format-2d450d95-2630-43b8-bf06-ccee7cbe6864?ui=en-US&rs=en-US&ad=US> 

B<Returns:> a L<Type::Tiny> object

=back

=head2 Attributes

Data passed to new when creating an instance.  For modification of these attributes 
see the listed 'attribute methods'. For more information on attributes see 
L<Moose::Manual::Attributes>.

=head3 error_inst

=over

B<Definition:> This attribute holds an 'error' object instance.  It should have 
several methods for managing errors.  Currently no error codes or error language 
translation options are available but this should make implementation of that 
easier.

B<Default:> a L<Spreadsheet::XLSX::Reader::LibXML::Error> instance with the 
attributes set as;
	
	( should_warn => 0 )

B<Range:> The minimum list of methods to implement for your own instance is;

	error set_error clear_error set_warnings if_warn
	
The error instance must be able to extract the error string from a passed error 
object as well.  For now the current implementation will attempt ->as_string first 
and then ->message if an object is passed.

B<attribute methods> Methods provided to adjust this attribute

=over

B<get_error_inst>

=over

B<Definition:> returns this instance

=back

B<error>

=over

B<Definition:> delegated method from the class used to get the most recently 
logged error string

=back

B<set_error>

=over

B<Definition:> delegated method from the class used to set a new error string 
(or pass an error object for extraction of the error string)

=back

B<clear_error>

=over

B<Definition:> delegated method from the class used to clear the current error 
string

=back

B<set_warnings>

=over

B<Definition:> delegated method from the class used to turn on or off real time 
warnings when errors are set

=back

B<if_warn>

=over

B<Definition:> delegated method from the class used to extend this package and 
see if warnings should be emitted.

=back
		
=back

=back

=head3 file_name

=over

B<Definition:> This attribute holds the full file name and path for the 
xlsx file to be parsed.

B<Default> no default - either this or a L<file handle|/file_handle> must be 
provided to read a file

B<Range> any unencrypted xlsx file that can be opened in Microsoft Excel

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<set_file_name>

=over

B<Definition:> change the file name value in the attribute (this will reboot 
the workbook instance)

=back

B<has_file_name>

=over

B<Definition:> this is used to see if the workbook loaded correctly using the 
file_name option to open an Excel .xlsx file.

=back

=back

=back

=head3 file_handle

=over

B<Definition:> This attribute holds a copy of the passed file handle reference.

B<Default> no default - either this or a L<file name|/file_name> must be 
provided to read a file

B<Range> any unencrypted xlsx file handle that can be opened in Microsoft Excel

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<set_file_handle>

=over

B<Definition:> change the set file handle (this will reboot the workbook instance)

=back

B<has_file_handle>

=over

B<Definition:> this is used to see if the workbook loaded correctly when using the 
file_handle option to open an Excel .xlsx file.

=back

=back

=back

=head3 file_creator

=over

B<Definition:> This holds the information stored in the Excel file metadata 
about who created the file originally.  B<You shouldn't set this attribute 
yourself.>

B<Default> the value from the file

B<Range> A string

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<creator>

=over

B<Definition:> returns the name string of the file creator

=back

=back

=back

=head3 file_date_created

=over

B<Definition:> This holds the created date in the Excel file metadata 
for when the file was first built.  B<You shouldn't set this attribute 
yourself.>

B<Default> the value from the file

B<Range> A timestamp string (ISO ish)

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<date_created>

=over

B<Definition:> returns the date the file was created

=back

=back

=back

=head3 file_modified_by

=over

B<Definition:> This holds the information stored in the Excel Metadata 
for who modified the file last.  B<You shouldn't set this attribute 
yourself.>

B<Default> the value from the file

B<Range> A string

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<modified_by>

=over

B<Definition:> returns the user name of the person who last modified the file

=back

=back

=back

=head3 file_date_modified

=over

B<Definition:> This holds the last modified date in the Excel Metadata 
for when the file was last changed.  B<You shouldn't set this attribute 
yourself.>

B<Default> the value from the file

B<Range> A timestamp string (ISO ish)

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<date_modified>

=over

B<Definition:> returns the date when the file was last modified

=back

=back

=back

=head3 sheet_parser

=over

B<Definition:> This sets the way the .xlsx file is parsed.  For now the only 
choice is 'reader'.

B<Default> 'reader'

B<Range> 'reader'

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<set_parser_type>

=over

B<Definition:> the way to change the parser type

=back

B<get_parser_type>

=over

B<Definition:> returns the currently set parser type

=back

=back

=back

=head3 count_from_zero

=over

B<Definition:> Excel spreadsheets count from 1.  L<Spreadsheet::ParseExcel> 
counts from zero.  This allows you to choose either way.

B<Default> 1

B<Range> 1 = counting from zero like Spreadsheet::ParseExcel, 
0 = Counting from 1 like Excel

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<counting_from_zero>

=over

B<Definition:> a way to check the current attribute setting

=back

B<set_count_from_zero>

=over

B<Definition:> a way to change the current attribute setting

=back

=back

=back

=head3 file_boundary_flags

=over

B<Definition:> When you request data to the right of the last column or below 
the last row of the data this package can return 'EOR' or 'EOF' to indicate that 
state.  This is especially helpful in 'while' loops.  The other option is to 
return 'undef'.  This is problematic if some cells in your table are empty which 
also returns undef.  What is determined to be the last column and row is determined 
by the attribute L<empty_is_end|/empty_is_end>.

B<Default> 1

B<Range> 1 = return 'EOR' or 'EOF' flags as appropriate, 0 = return undef when 
requesting a position that is out of bounds

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<boundary_flag_setting>

=over

B<Definition:> a way to check the current attribute setting

=back

B<change_boundary_flag>

=over

B<Definition:> a way to change the current attribute setting

=back

=back

=back

=head3 empty_is_end

=over

B<Definition:> The excel convention is to read the table left to right and top 
to bottom.  Some tables have an uneven number of columns with real data from row 
to row.  This allows the several methods that excersize a 'next' function to wrap 
after the last element with data rather than going to the max column.  This also 
triggers 'EOR' flags after the last data element and befor the sheet max 
column when not implementing 'next' functionality.

B<Default> 0

B<Range> 1 = treat all columns short of the max column for the sheet as being in 
the table, 0 = end each row after the last cell with data rather than going to the 
max sheet column

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<is_empty_the_end>

=over

B<Definition:> a way to check the current attribute setting

=back

B<set_empty_is_end>

=over

B<Definition:> a way to set the current attribute setting

=back

=back

=back

=head3 from_the_edge

=over

B<Definition:> Some data tables start in the top left corner.  Others do not.  I 
don't reccomend that practice but when aquiring data in the wild it is often good 
to adapt.  This attribute sets whether the file reads from the top left edge or from 
the top row with data and starting from the leftmost column with data.

B<Default> 1

B<Range> 1 = treat the top left corner of the sheet as the beginning of rows and 
columns even if there is no data in the top row or leftmost column, 0 = Set the 
minimum row and minimum columns to be the first row and first column with data

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<set_from_the_edge>

=over

B<Definition:> a way to set the current attribute setting

=back

=back

=back

=head3 default_format_list

=over

B<Definition:> This is the attribute containing the L<role|Moose::Manual::Roles> that 
manages the way number formats and encoding conversions are implemented for this sheet.  
This is a departure from L<Spreadsheet::ParseExcel> for two reasons.  First, it doesn't 
use the same modules.  Second, this requires a Moose role (not a class) with two methods 
where ParseExcel uses an object instance.

B<Default> L<Spreadsheet::XLSX::Reader::LibXML::FmtDefault>

B<Range> a L<Moose> role with the methods 'get_defined_excel_format' and 
'change_output_encoding' it should be noted that libxml2 which is the underlying code 
for L<XML::LibXML> always attempts to get the data into perl friendly strings based on the 
xml file encoding setting.  That means this role should only tweak the data on the way out 
of memory and does not operate on the data on its way into memory.

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<get_default_format_list>

=over

B<Definition:> a way to check the current attribute setting

=back

B<set_default_format_list>

=over

B<Definition:> a way to set the current attribute setting

=back

=back

=back

=head3 format_string_parser

=over

B<Definition:> This is a Moose role that interprets the excel L<format string
|https://support.office.com/en-us/article/Create-or-delete-a-custom-number-format-2d450d95-2630-43b8-bf06-ccee7cbe6864?ui=en-US&rs=en-US&ad=US> 
into a L<Type::Tiny> coercion.  If you don't like the output or the method 
you can write your own Moose Role and add it here.

B<Default> L<Spreadsheet::XLSX::Reader::LibXML::ParseExcelFormatStrings>

B<Range> a L<Moose> role with the method 'parse_excel_format_string'

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<get_format_string_parser>

=over

B<Definition:> a way to check the current attribute setting

=back

B<set_format_string_parser>

=over

B<Definition:> a way to set the current attribute setting

=back

=back

=back

=head3 group_return_type

=over

B<Definition:> Traditionally ParseExcel returns a cell object with lots of methods 
to reveal information about the cell.  In reality the extra information is not used very 
much (witness the popularity of L<Spreadsheet::XLSX>).  Because many users don't need or 
want the extra cell formatting information it is possible to get either the raw cell value 
or the formatted cell value returned either the way the Excel file specified or the way you 
specify instead of a Cell instance with all the data. .  See 
L<Spreadsheet::XLSX::Reader::LibXML::Worksheet/custom_formats> to insert custom targeted 
formats for use with the parser.  All empty cells return undef no matter what.

B<Default> instance

B<Range> instance = returns a populated L<Spreadsheet::XLSX::Reader::LibXML::Cell> instance,
unformatted = returns just the raw value of the cell with no modifications, value = returns 
just the formatted value stored in the excel cell

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<get_group_return_type>

=over

B<Definition:> a way to check the current attribute setting

=back

B<set_group_return_type>

=over

B<Definition:> a way to set the current attribute setting

=back

=back

=back

=head3 empty_return_type

=over

B<Definition:> Traditionally L<Spreadsheet::ParseExcel> returns an empty string for cells 
with unique formatting but no stored value.  It may be that the more accurate way of returning 
undef works better for you.  This will turn that behaviour on.  I<If Excel stores an empty 
string having this attribute set to 'undef_string' will still return the empty string!>

B<Default> empty_string

B<Range>
	empty_string = populates the unformatted value with '' even if it is set to undef
	undef_string = if excel stores undef for an unformatted value it will return undef

B<attribute methods> Methods provided to adjust this attribute
		
=over

B<get_empty_return_type>

=over

B<Definition:> a way to check the current attribute setting

=back

B<set_empty_return_type>

=over

B<Definition:> a way to set the current attribute setting

=back

=back

=back

=head1 BUILD / INSTALL from Source

B<1.> Ensure that you have the libxml2 B<and libxml2-devel> libraries installed using 
your favorite system package installer.  One way to check if it is already installed 
is to attempt to install L<XML::LibXML> separatly with cpan.

=over

L<http://xmlsoft.org/>

=back
	
B<2.> Download a compressed file with this package code from your favorite source

=over

L<Meta::CPAN|https://metacpan.org/pod/Spreadsheet::XLSX::Reader::LibXML>

L<github|https://github.com/jandrew/Spreadsheet-XLSX-Reader-LibXML>

L<CPAN|http://search.cpan.org/~jandrew/Spreadsheet-XLSX-Reader-LibXML/>

=back
	
B<3.> Extract the code from the compressed file.

=over

If you are using tar on a .tar.gz file this should work:

	tar -zxvf Spreadsheet-XLSX-Reader-LibXML-v0.xx.tar.gz
	
=back

B<4.> Change (cd) into the extracted directory

B<5.> Run the following

=over

(for Windows find what version of make was used to compile your perl)

	perl  -V:make
	
(then for Windows substitute the correct make function (s/make/dmake/g)? below)
	
=back

	>perl Makefile.PL

	>make

	>make test

	>make install # As sudo/root

	>make clean

=head1 SUPPORT

=over

L<github Spreadsheet::XLSX::Reader::LibXML/issues|https://github.com/jandrew/Spreadsheet-XLSX-Reader-LibXML/issues>

=back

=head1 TODO

=over

B<1.> Build an 'Alien::LibXML::Devel' package to load the libxml2-devel libraries from source and 
require that and L<Alien::LibXML> in the build file. So all needed requirements for L<XML::LibXML> 
are met

=over

Both libxml2 and libxml2-devel libraries are required for XML::LibXML

=back

B<2.> Add a pivot table reader (Not just read the values from the sheet)

B<3.> Add calc chain methods

B<4.> Add more exposure to workbook formatting methods

B<5.> Build a DOM parser alternative for the sheets

=over

(Theoretically faster than the reader but uses more memory)

=back

B<6.> Make L</empty_is_end> finish a sheet for rows with formatting but no data.  
Possibly this requires an additional attribute 'next_ignores_empty'?

=back

=head1 AUTHOR

=over

=item Jed Lund

=item jandrew@cpan.org

=back

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

This software is copyrighted (c) 2014 by Jed Lund

=head1 DEPENDENCIES

=over

L<perl 5.010|perl/5.10.0>

L<Archive::Zip>

L<Carp>

L<Clone>

L<DateTime::Format::Flexible>

L<DateTimeX::Format::Excel>

L<IO::File>

L<List::Util> - 1.33

L<Moose> - 2.1213

L<MooseX::HasDefaults::RO>

L<MooseX::ShortCut::BuildInstance> - 1.032

L<MooseX::StrictConstructor>

L<Type::Tiny> - 1.000

L<XML::LibXML>

L<version> - 0.077

=back

=head1 SEE ALSO

=over

L<Spreadsheet::ParseExcel> - Excel 2003 and earlier

L<Spreadsheet::XLSX> - 2007+

L<Spreadsheet::ParseXLSX> - 2007+

L<Log::Shiras|https://github.com/jandrew/Log-Shiras>

=over

All lines in this package that use Log::Shiras are commented out

=back

=back

=cut

#########1#########2 main pod documentation end  5#########6#########7#########8#########9