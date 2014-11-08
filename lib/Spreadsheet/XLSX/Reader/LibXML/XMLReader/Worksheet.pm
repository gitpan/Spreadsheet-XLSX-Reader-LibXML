package Spreadsheet::XLSX::Reader::LibXML::XMLReader::Worksheet;
BEGIN {
  $Spreadsheet::XLSX::Reader::LibXML::XMLReader::Worksheet::AUTHORITY = 'cpan:JANDREW';
}
use version; our $VERSION = qv('v0.5_1');


use	5.010;
use	Moose;
use	MooseX::StrictConstructor;
use	MooseX::HasDefaults::RO;
use Types::Standard qw(
		Int				Str				ArrayRef
		HashRef			HasMethods		Bool
    );
use lib	'../../../../../../lib';
###LogSD	use Log::Shiras::Telephone;
###LogSD	use Log::Shiras::UnhideDebug;
extends	'Spreadsheet::XLSX::Reader::LibXML::XMLReader';
with	'Spreadsheet::XLSX::Reader::LibXML::CellToColumnRow',
		'Spreadsheet::XLSX::Reader::LibXML::XMLReader::XMLToPerlData',
		;# See row 69 for an additional Role

#########1 Dispatch Tables & Package Variables    5#########6#########7#########8#########9

my	$cell_name_translation = {
		f => 'cell_formula',
		v => 'raw_value',
	};

#########1 Public Attributes  3#########4#########5#########6#########7#########8#########9

has sheet_rel_id =>(
		isa		=> Str,
		reader	=> 'rel_id',
	);

has sheet_id =>(
		isa		=> Int,
		reader	=> 'sheet_id',
	);

has sheet_position =>(# XML position
		isa		=> Int,
		reader	=> 'position',
	);

has sheet_name =>(
		isa		=> Str,
		reader	=> 'name',
	);

has workbook_instance =>(
		isa		=> HasMethods[qw(
						counting_from_zero			boundary_flag_setting
						change_boundary_flag		_has_shared_strings_file
						get_shared_string_position	_has_styles_file
						get_format_position			set_empty_is_end
						is_empty_the_end			_starts_at_the_edge
						get_group_return_type		set_group_return_type
						get_epoch_year
					)],
		handles	=> [qw(
						counting_from_zero			boundary_flag_setting
						change_boundary_flag		_has_shared_strings_file
						get_shared_string_position	_has_styles_file
						get_format_position			set_empty_is_end
						is_empty_the_end			_starts_at_the_edge
						get_group_return_type		set_group_return_type
						get_epoch_year
					)],
		required => 1,
	);
###LogSD	use Log::Shiras::UnhideDebug;
with 'Spreadsheet::XLSX::Reader::LibXML::GetCell';

#########1 Public Methods     3#########4#########5#########6#########7#########8#########9

sub min_row{
	my( $self ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> ($self->get_log_space .  '::row_bound::min_row' ), );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			"Returning the minimum row: " . $self->_min_row ] );
	return $self->_min_row;
}

sub max_row{
	my( $self ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> ($self->get_log_space .  '::row_bound::max_row' ), );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			"Returning the maximum row: " . $self->_max_row ] );
	return $self->_max_row;
}

sub min_col{
	my( $self ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> ($self->get_log_space .  '::row_bound::min_col' ), );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			"Returning the minimum column: " . $self->_min_col ] );
	return $self->_min_col;
}

sub max_col{
	my( $self ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> ($self->get_log_space .  '::row_bound::max_col' ), );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			"Returning the maximum column: " . $self->_max_col ] );
	return $self->_max_col;
}

sub row_range{
	my( $self ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> ($self->get_log_space .  '::row_bound::row_range' ), );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			"Returning row range( " . $self->_min_row . ", " . $self->_max_row . " )" ] );
	return( $self->_min_row, $self->_max_row );
}

sub col_range{
	my( $self ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> ($self->get_log_space .  '::row_bound::col_range' ), );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			"Returning col range( " . $self->_min_col . ", " . $self->_max_col . " )" ] );
	return( $self->_min_col, $self->_max_col );
}


#########1 Private Attributes 3#########4#########5#########6#########7#########8#########9

has _sheet_min_col =>(
		isa			=> Int,
		writer		=> '_set_min_col',
		reader		=> '_min_col',
		predicate	=> 'has_min_col',
	);

has _sheet_min_row =>(
		isa			=> Int,
		writer		=> '_set_min_row',
		reader		=> '_min_row',
		predicate	=> 'has_min_row',
	);

has _sheet_max_col =>(
		isa			=> Int,
		writer		=> '_set_max_col',
		reader		=> '_max_col',
		predicate	=> 'has_max_col',
	);

has _sheet_max_row =>(
		isa			=> Int,
		writer		=> '_set_max_row',
		reader		=> '_max_row',
		predicate	=> 'has_max_row',
	);

has _last_row_col =>(
		isa			=> ArrayRef[Int],
		reader		=> '_get_last_row_col',
		writer		=> '_set_last_row_col',
		predicate	=> '_has_last_row_col',
	);

has _last_cell_ref =>(
		isa			=> HashRef,
		reader		=> '_get_last_cell_ref',
		writer		=> '_set_last_cell_ref',
		clearer		=> '_clear_last_cell_ref',
		predicate	=> '_has_last_cell_ref',
	);

has _next_row_col =>(
		isa			=> ArrayRef[Int],
		reader		=> '_get_next_row_col',
		writer		=> '_set_next_row_col',
		predicate	=> '_has_next_row_col',
	);

has _next_cell_ref =>(
		isa			=> HashRef,
		reader		=> '_get_next_cell_ref',
		writer		=> '_set_next_cell_ref',
		clearer		=> '_clear_next_cell_ref',
		predicate	=> '_has_next_cell_ref',
	);

has	_merge_map =>(
		isa		=> ArrayRef,
		traits	=> ['Array'],
		writer	=> '_set_merge_map',
		handles	=>{
			_get_row_merge_map => 'get',
		},
	);

has _reported_col =>(
		isa			=> Int,
		writer		=> '_set_reported_col',
		reader		=> '_get_reported_col',
	);

has _reported_row =>(
		isa			=> Int,
		writer		=> '_set_reported_row',
		reader		=> '_get_reported_row',
	);

#########1 Private Methods    3#########4#########5#########6#########7#########8#########9

sub _load_unique_bits{
	my( $self, ) = @_;#, $new_file, $old_file
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> ($self->get_log_space . '::_load_unique_bits' ), );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			"Setting the Worksheet unique bits", "Byte position: " . $self->byte_consumed ] );
	
	# Read the sheet dimensions
	if( $self->next_element( 'dimension' ) ){
		my	$range = $self->get_attribute( 'ref' );
		my	( $start, $end ) = split( /:/, $range );
		###LogSD	$phone->talk( level => 'debug', message => [
		###LogSD		"Start position: $start", "End position: $end", "Byte position: " . $self->byte_consumed ] );
		my ( $start_column, $start_row ) = ( $self->_starts_at_the_edge ) ?
												( 1, 1 ) : $self->_parse_column_row( $start );
		my ( $end_column, $end_row	) = $self->_parse_column_row( $end );
		###LogSD	$phone->talk( level => 'debug', message => [
		###LogSD		"Start column: $start_column", "Start row: $start_row",
		###LogSD		"End column: $end_column", "End row: $end_row" ] );
		$self->_set_min_col( $start_column );
		$self->_set_min_row( $start_row );
		$self->_set_max_col( $end_column );
		$self->_set_max_row( $end_row );
		$self->_set_last_row_col( [$start_row, ($start_column - 1)] );
		$self->_clear_last_cell_ref;
		$self->_set_next_row_col( [$start_row, ($start_column - 1)] );
		$self->_clear_next_cell_ref;
		$self->_set_reported_row( $start_row );
		$self->_set_reported_col( $start_column - 1 );
	}else{
		$self->_set_error( "No sheet dimensions provided" );
	}
	
	#build a merge map
	my	$merge_ref = [];
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"Loading the mergeCell" ] );
	while( $self->next_element('mergeCell') ){
		my	$merge_range = $self->get_attribute( 'ref' );
		###LogSD	$phone->talk( level => 'debug', message => [
		###LogSD		"Loading the merge range for: $merge_range", "Byte position: " . $self->byte_consumed ] );
		my ( $start, $end ) = split /:/, $merge_range;
		my ( $start_col, $start_row ) = $self->_parse_column_row( $start );
		my ( $end_col, $end_row ) = $self->_parse_column_row( $end );
		my 	$min_col = $start_col;
		while ( $start_row <= $end_row ){
			$merge_ref->[$start_row]->[$start_col] = $merge_range;
			$start_col++;
			if( $start_col > $end_col ){
				$start_col = $min_col;
				$start_row++;
			}
		}
	}
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"Final merge ref:", $merge_ref ] );
	$self->_set_merge_map( $merge_ref );
	$self->start_the_file_over;
	return 1;
}

sub _get_next_value_cell{
	my( $self, ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> ($self->get_log_space . '::_get_next_value_cell' ), );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			'Loading the next cell with value after [row, column]: [' .
	###LogSD			join( ', ', @{$self->_get_next_row_col} ) . ']'] );
	my	$result = 1;
		$result = $self->next_element( 'c' ) if !$self->node_name or $self->node_name ne 'c';
	my	$sub_ref = 'EOF';
	if( !$result ){
		###LogSD	$phone->talk( level => 'debug', message => [
		###LogSD			'Reached the end of the file',] );
		$self->start_the_file_over;
	}else{
		$sub_ref = $self->parse_element;
		@$sub_ref{qw( col row )} = $self->_parse_column_row( $sub_ref->{r} );
		###LogSD	$phone->talk( level => 'trace', message => [
		###LogSD		'The next cell with data is:', $sub_ref,] );
	}
	
	#Add merge value
	if( $sub_ref and ref( $sub_ref ) ){
		my $merge_row = $self->_get_row_merge_map( $sub_ref->{row} );
		if( ref( $merge_row ) and $merge_row->[$sub_ref->{col}] ){
			$sub_ref->{cell_merge} = $merge_row->[$sub_ref->{col}];
		}
	}
	###LogSD	$phone->talk( level => 'trace', message => [
	###LogSD		'Ref to this point:', $sub_ref,] );
	
	# move current to prior
	if( $self->_has_next_cell_ref ){
		###LogSD	$phone->talk( level => 'trace', message => [
		###LogSD		'Saving the next ref as the last ref:', $self->_get_next_cell_ref,] );
		$self->_set_last_cell_ref( $self->_get_next_cell_ref );
		$self->_set_last_row_col( $self->_get_next_row_col );
	}
	
	#load current
	if( ref $sub_ref ){
		###LogSD	$phone->talk( level => 'trace', message => [
		###LogSD		'Saving the next ref data in the attributes:', $sub_ref] );
		$self->_set_next_cell_ref( $sub_ref );
		$self->_set_next_row_col( [ @$sub_ref{qw( row col )} ] );
		$self->_set_reported_row( $sub_ref->{row} );
		$self->_set_reported_col( $sub_ref->{col} );
	}else{
		###LogSD	$phone->talk( level => 'trace', message => [
		###LogSD		'Past the EOF so saving the empty ref and position [row, col]: [' .
		###LogSD		($self->_max_row + 1) . ', ' . $self->_min_col . ']',, caller(1)] );
		$self->_clear_next_cell_ref;
		$self->_set_next_row_col( [($self->_max_row + 1), $self->_min_col ] );
		$self->_set_reported_row( $self->_min_row );
		$self->_set_reported_col( $self->_min_col - 1 );
	}
	
	return $sub_ref;
}

sub _get_next_cell{
	my( $self, ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> ($self->get_log_space . '::_get_next_cell' ), );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			'Loading the next cell after [row, column]: [' . $self->_get_reported_row .
	###LogSD			', ' . $self->_get_reported_col . ']',] );
	my ( $next_row, $next_col ) = @{$self->_get_next_row_col};
	my	$target_row = $self->_get_reported_row;
	my	$target_col = $self->_get_reported_col + 1;
	if( $target_col > $self->_max_col ){
		$target_row++;
		$target_col = $self->_min_col;
	}
	# check if an index reset is needed (transition case from a different parsing method)
	if(	$target_row < $self->_get_last_row_col->[0] ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'Starting the sheet over' ] );
		$self->_set_next_row_col( [ $self->_min_row, ($self->_min_col - 1) ] );
		$self->_set_last_row_col( [ @{$self->_get_next_row_col} ] );
		$self->_clear_last_cell_ref;
		( $next_row, $next_col ) = @{$self->_get_next_row_col} ;
	}
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		'Searching for [row, column]: [' . $target_row . ', ' . $target_col . ']',] );
	my	$result = 'NoAdvance';
	if( $target_row <= $self->_max_row ){
		while( ( $target_row > $next_row ) or
				( $target_row == $next_row and $target_col > $next_col ) ){
			$result = $self->_get_next_value_cell;
			if( $result eq 'EOF' ){
				( $next_row, $next_col ) = ( ($self->_max_row + 1), $self->_min_row );
				last;
			}
			( $next_row, $next_col ) = @$result{qw( row col )};
		}
	}
	$self->_set_reported_row( $target_row );
	$self->_set_reported_col( $target_col );
	###LogSD	$phone->talk( level => 'debug', message =>[ 'Advanced to:', $result ] );
	
	# check for EOF and empty cells(no EOR in a _next_xxx scenario) 
	if(	$target_row > $self->_max_row or # Maximum EOF
		$self->is_empty_the_end and $result eq 'EOF' ){ # Stop when empty EOF
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'Reached the end of EOF state for target [row, col]: [' .
		###LogSD		$target_row . ', ' . $target_col . ']', '..or got an earl EOF' ] );
		$self->_set_reported_row( $self->_min_row );
		$self->_set_reported_col( $self->_min_col - 1 );
		$self->_set_next_row_col( [ $self->_min_row, ($self->_min_col - 1) ] );
		return 'EOF';
	}elsif( !$self->is_empty_the_end and $next_row > $target_row ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'Found an empty cell at the end of the row for [row, col]: [' .
		###LogSD		$target_row . ', ' . $target_col . ']' ] );
		return undef;
	}elsif( $self->is_empty_the_end and $next_row > $target_row ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'Wrapping the row for [row, col]: [' . $target_row . ', ' . $target_col . ']' ] );
		$target_row = $self->_set_reported_row( $target_row + 1 );
		$target_col = $self->_set_reported_col( $self->_min_col );
		if( $next_row == ($target_row) and $next_col == $self->_min_col ){
			###LogSD	$phone->talk( level => 'debug', message =>[
			###LogSD		'Found a result at [row, col]: [' . $target_row . ', ' . $target_col . ']' ] );
			return $self->_get_next_cell_ref;
		}else{
			###LogSD	$phone->talk( level => 'debug', message =>[
			###LogSD		'Found an empty cell at the beginning of the next row' ] );
			return undef;
		}
	}elsif( $next_row == $target_row and $next_col > $target_col ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'Found and empty cell at [row, col]: [' . $target_row . ', ' . $target_col . ']' ] );
		return undef;
	}elsif( $result eq 'NoAdvance' ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'Retreiving the stored value for [row, col]: [' . $target_row . ', ' . $target_col . ']' ] );
		$result = $self->_get_next_cell_ref;
	}		
	###LogSD	$phone->talk( level => 'debug', message =>[
	###LogSD		'Found a result at [row, col]: [' . $target_row . ', ' . $target_col . ']' ] );
	return $result;
}

sub _get_col_row{
	my( $self, $column, $row ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> ($self->get_log_space . '::_get_col_row' ), );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			'Getting [column, row]: [' . (($column) ? $column : undef) .
	###LogSD			', ' . (($row) ? $row : undef) . ']',] );
	
	# Validate
	if( !$column or !$row ){
		$self->set_error( "Missing either a passed column or row" );
		return undef;
	}
	
	# See if you went too far
	if( $row > $self->_max_row ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		"Requested row -$row- is greater than the max row: " . $self->_max_row ] );
		return 'EOF';
	}
	if( $column > $self->_max_col ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		"Requested column -$column- is greater than the max column: " . $self->_max_col ] );
		return (($row == $self->_max_row) ? 'EOF' : 'EOR');
	}
	
	# check if an index reset is needed
	my	$result = 'NoAdvance';
	if(	$row < $self->_get_last_row_col->[0] or
		$row == $self->_get_last_row_col->[0] and $column < $self->_get_last_row_col->[1]){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'Starting the sheet over' ] );
		$self->_set_next_row_col( [ $self->_min_row, ($self->_min_col - 1) ] );
		$self->_set_last_row_col( [ @{$self->_get_next_row_col} ] );
		$self->_clear_last_cell_ref;
		$self->_clear_next_cell_ref;
		$self->start_the_file_over;
		$self->_set_reported_row( $self->_min_row );
		$self->_set_reported_col( $self->_min_col - 1 );
	}
	my ( $next_row, $next_col ) = @{$self->_get_next_row_col};
	
	# Move to bracket the target value
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		'Searching for [column, row]: [' . $column . ', ' . $row . ']',] );
	while( ( $row > $next_row ) or
			( $row == $next_row and $column > $next_col ) ){
		$result = $self->_get_next_value_cell;
		if( $result eq 'EOF' ){
			( $next_row, $next_col ) = ( ($self->_max_row + 1), $self->_min_row );
			last;
		}
		( $next_row, $next_col ) = @$result{qw( row col )};
	}
	$self->_set_reported_row( $row );
	$self->_set_reported_col( $column );
	###LogSD	$phone->talk( level => 'debug', message =>[ 'Advanced to:', $result ] );
	
	# check for EOF, EOR, and empty cells
	if(	$row == $next_row and $column == $next_col ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'Found data at (next) [row, col]: [' .
		###LogSD		$row . ', ' . $column . ']', ] );
		return $self->_get_next_cell_ref;
	}elsif( $row == $self->_get_last_row_col->[0] and $column == $self->_get_last_row_col->[1] ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'Found data at the (last) [row, col]: [' .
		###LogSD		$row . ', ' . $column . ']', ] );
		$self->_set_reported_row( $self->_get_last_row_col->[0] );
		$self->_set_reported_col( $self->_get_last_row_col->[1] );
		return $self->_get_last_cell_ref;
	}elsif( $self->is_empty_the_end and $next_row > $self->_max_row ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'Reached the end of file (EOF) state for target [row, col]: [' .
		###LogSD		$row . ', ' . $column . ']', ] );
		$self->_set_reported_row( $self->_min_row );
		$self->_set_reported_col( $self->_min_col - 1 );
		$self->_set_next_row_col( [ $self->_min_row, ($self->_min_col - 1) ] );
		return 'EOF';
	}elsif( $self->is_empty_the_end and $next_row > $row ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'Reached the end of row (EOR) state for target [row, col]: [' .
		###LogSD		$row . ', ' . $column . ']', ] );
		return 'EOR';
	}
	###LogSD	$phone->talk( level => 'debug', message =>[
	###LogSD		'Found an empty cell at [row, col]: [' . $row . ', ' . $column . ']' ] );
	return undef;
}

sub _get_row_all{
	my( $self, $row ) = @_;
	###LogSD	my	$phone = Log::Shiras::Telephone->new(
	###LogSD					name_space 	=> ($self->get_log_space . '::_get_row_all' ), );
	###LogSD		$phone->talk( level => 'debug', message => [
	###LogSD			'Getting row: ' . (($row) ? $row : undef) ] );
	# Validate
	if( !$row ){
		$self->set_error( "Need to pass a row number - non passed" );
		return undef;
	}
	
	# See if you went too far
	if( $row > $self->_max_row ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		"Requested row -$row- is greater than the max row: " . $self->_max_row ] );
		$self->_set_next_row_col( [ $self->_min_row, ($self->_min_col - 1) ] );
		$self->_set_last_row_col( [ @{$self->_get_next_row_col} ] );
		$self->_clear_last_cell_ref;
		$self->_clear_next_cell_ref;
		$self->start_the_file_over;
		$self->_set_reported_row( $self->_min_row );
		$self->_set_reported_col( $self->_min_col - 1 );
		return 'EOF';
	}
	
	# check if an index reset is needed
	my	$result = 'NoAdvance';
	if(	$row < ($self->_get_last_row_col->[0] - 1 )  ){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'Starting the sheet over' ] );
		$self->_set_next_row_col( [ $self->_min_row, ($self->_min_col - 1) ] );
		$self->_set_last_row_col( [ @{$self->_get_next_row_col} ] );
		$self->_clear_last_cell_ref;
		$self->_clear_next_cell_ref;
		$self->start_the_file_over;
		$self->_set_reported_row( $self->_min_row );
		$self->_set_reported_col( $self->_min_col - 1 );
	}
	my ( $next_row, $next_col ) = @{$self->_get_next_row_col};
	
	# Move to bracket the target value
	###LogSD	$phone->talk( level => 'debug', message => [
	###LogSD		"Searching for row: $row", "..against next row: $next_row" ] );
	while( $row > $next_row ){
		$result = $self->_get_next_value_cell;
		if( $result eq 'EOF' ){
			( $next_row, $next_col ) = ( ($self->_max_row + 1), $self->_min_row );
			last;
		}
		( $next_row, $next_col ) = @$result{qw( row col )};
	}
	###LogSD	$phone->talk( level => 'debug', message =>[ 'Advanced to:', $result ] );
	
	# check for EOF and empty rows
	if( $row > $self->_get_last_row_col->[0] and
		$row < $self->_get_next_row_col->[0]		){
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		"Found an empty row at: $row", 'Need to determine if it is is an EOF', ] );
		$self->_set_reported_col( $self->_max_col );
		$self->_set_reported_row( $row );
		if( $self->_get_next_row_col->[0] > $self->_max_row ){
			###LogSD	$phone->talk( level => 'debug', message =>[
			###LogSD		'Found a weird end of file before max row', ] );
			$self->_set_next_row_col( [ $self->_min_row, ($self->_min_col - 1) ] );
			$self->_set_last_row_col( [ @{$self->_get_next_row_col} ] );
			$self->_clear_last_cell_ref;
			$self->_clear_next_cell_ref;
			$self->start_the_file_over;
			$self->_set_reported_row( $self->_min_row );
			$self->_set_reported_col( $self->_min_col - 1 );
			return 'EOF';
		}elsif( $self->is_empty_the_end ){
			###LogSD	$phone->talk( level => 'debug', message =>[
			###LogSD		"Don't fill in empty stuff", ] );
			return [];
		}else{
			my $answer;
			for( $self->_min_col .. $self->_max_col ){
				push @$answer, undef;
			}
			return $answer;
		}
	}
	
	# build the row ref
	my	$column = $self->_min_col;
		$result = undef;
	my	$x = 0;
	my	$answer_ref = [];
	while( $x < 17000 ){ #Excel 2013 goes to 16,384 columns
		$result = $self->_get_col_row( $column, $row );
		###LogSD	$phone->talk( level => 'debug', message =>[
		###LogSD		'collecting the data at [row, col]: [' .
		###LogSD		$row . ', ' . $column . ']', '..with result:', $result ] );
		last if ($result and ($result eq 'EOR' or $result eq 'EOF'));
		push @$answer_ref, $result;
		$column++;
		$x++;
	}
	$self->_set_reported_row( $row );
	$self->_set_reported_col( $column );
	
	###LogSD	$phone->talk( level => 'debug', message =>[
	###LogSD		'Final answer:', $answer_ref ] );
	return $answer_ref;
}

#########1 Phinish            3#########4#########5#########6#########7#########8#########9

no Moose;
__PACKAGE__->meta->make_immutable(
	inline_constructor => 0,
);
	
1;

#########1 Documentation      3#########4#########5#########6#########7#########8#########9
__END__

=head1 NAME

Spreadsheet::XLSX::Reader::LibXML::XMLReader::Worksheet - A class for exploring XLSX worksheets

=head1 SYNOPSIS

See the SYNOPSIS in L<Spreadsheet::XLSX::Reader::LibXML>
    
=head1 DESCRIPTION

This is the class used to interrogate Excel xlsx worksheets for information.  Because 
the Excel xlsx storage of information can be (but not always) spread across multiple xml 
files this class is the way to retreive information about the sheet independant of which 
file it is in.  This is the L<XMLReader|Spreadsheet::XLSX::Reader::LibXML::XMLReader> 
version of this class.  Where possible this class makes the decision to read files by line 
rather than parse the file using a DOM tree.  The up side to this is that large files will 
(hopefully) not crash when opened and the data will available using the same methods.  
The down side is that the file opens slower since the whole sheet is read twice before 
information is available.  Additionally data is best accessed sequentially left to right 
and top to bottom since going back will involve a system file close and re-open action.

=head2 Attributes

Attributes of this cell are not included in the documentation because 'new' should be 
called by L<other|Spreadsheet::XLSX::Reader::LibXML> classes in this package.

=head2 Methods

These are ways to access the data and formats in the cell.  They also provide a 
way to modifiy the output of the format.

=head3 get_name

=over

B<Definition:> Returns the sheet name

B<Accepts:>Nothing

B<Returns:> $sheet_name

=back

=head3 row_range

=over

B<Definition:> Returns the minimum row number and the maximum row number based on the 
settings of attribute 'count_from_zero' set when first creating the file parser with 
L<Spreadsheet::XLSX::Reader::LibXML>.

B<Accepts:>Nothing

B<Returns:> a list of ( $minimum_row, $max_row )

=back

=head3 col_range

=over

B<Definition:> Returns the minimum column number and the maximum column number based on 
the settings of attribute 'count_from_zero' set when first creating the file parser with 
L<Spreadsheet::XLSX::Reader::LibXML>.

B<Accepts:>Nothing

B<Returns:> a list of ( $minimum_column, $max_column )

=back

=head3 get_cell( $row, $column )

=over

B<Definition:> Returns a L<Spreadsheet::XLSX::Reader::LibXML::Cell> instance corresponding 
to the identified $row and $column.  The actual position returned are affected by the 
attribute 'count_from_zero' set when first creating the file parser with 
L<Spreadsheet::XLSX::Reader::LibXML>.  If there is no data stored in that cell it returns 
undef.  If the $column selected is past the L<max_col|/max_col> value then it returns the 
string 'EOR'.  If the $row selected is past the L<max_row|/max_row> value then it returns 
the string 'EOF'.

If both $row and $column are left blank this is effectivly a 'get_(next)_cell' command 
moving left to right and top to bottom starting from either the last position identified 
or the sheet minimum row and column.  When the end of the file is reached it returns the 
string 'EOF';

If only the $row is specified it will return the next cell in that $row starting from the 
last column specified I<even if it was a different row> or starting from the minimum column.  
When the row is finished it will return the string 'EOR' and reset the next column to be 
the minimum column.  (The sheet starts with the minimum column as the next column on 
opening.)  This implementation is pre-deprecated and will be removed when the 
'fetchrow_arrayref' function is implemented.  That that point this method will require 
either both $row and $column or neither.

If only the $column is specified this will return undef and set the 
L<error|Spreadsheet::XLSX::Reader::Error> message returning undef.  

B<Accepts:> ( $row, $column ) - as indicated in the Definition

B<Returns:> (undef|a blessed L<Spreadsheet::XLSX::Reader::LibXML::Cell> instance|'EOR'|'EOF')

=back
		
=head3 set_warnings( $bool )

=over

B<Definition:> Turn clucked warnings on or off from L<Spreadsheet::XLSX::Reader::LibXML::Error>

B<Accepts:> Boolean values

B<Returns:> nothing

=back
		
=head3 if_warn

=over

B<Definition:> Check the state of the boolean affected by L<set_warnings
|/set_warnings( $bool )> attribute value from L<Spreadsheet::XLSX::Reader::LibXML::Error>

B<Accepts:> Nothing

B<Returns:> $bool

=back
		
=head3 error

=over

B<Definition:> Returns the currently stored error string from 
L<Spreadsheet::XLSX::Reader::LibXML::Error>

B<Accepts:> Nothing

B<Returns:> $error_string

=back

=head3 clear_error

=over

B<Definition:> method to clear the current error string from 
L<Spreadsheet::XLSX::Reader::LibXML::Error>

B<Accepts:> Nothing

B<Returns:> Nothing (string is cleared)

=back

=head3 min_col

=over

B<Definition:> method to read the minimum column for the sheet

B<Accepts:> Nothing

B<Returns:> $minimum_column (Integer)

=back

=head3 has_min_col

=over

B<Definition:> indicates if a minimum column has been determined

B<Accepts:> Nothing

B<Returns:> $bool TRUE = exists

=back

=head3 min_row

=over

B<Definition:> method to read the minimum row for the sheet

B<Accepts:> Nothing

B<Returns:> $minimum_row (Integer)

=back

=head3 has_min_row

=over

B<Definition:> indicates if a minimum row has been determined

B<Accepts:> Nothing

B<Returns:> $bool TRUE = exists

=back

=head3 max_col

=over

B<Definition:> method to read the maximum column for the sheet

B<Accepts:> Nothing

B<Returns:> $maximum_column (Integer)

=back

=head3 has_max_col

=over

B<Definition:> indicates if a maximum column has been determaxed

B<Accepts:> Nothing

B<Returns:> $bool TRUE = exists

=back

=head3 max_row

=over

B<Definition:> method to read the maximum row for the sheet

B<Accepts:> Nothing

B<Returns:> $maximum_row (Integer)

=back

=head3 has_max_row

=over

B<Definition:> indicates if a maximum row has been determaxed

B<Accepts:> Nothing

B<Returns:> $bool TRUE = exists

=back

=head3 set_custom_formats( $hashref )

=over

B<Definition:> It is not inconceivable that the module user would need/want the data 
manipulated in some way that was not provided natively by excel.  This package uses 
the excellent L<Type::Tiny> to implement the default data manipulations identified 
by the spreadsheet.  However, it is possible for the user to supply a hashref of 
custom data manipulations.  The hashref is read where the key is a row-column 
indicator and the value is a data manipulation coderef/object that has (at least) 
the following two methods.  The first method is 'coerce' and the second method is 
'display_name'.  For each cell instance generated the L<get_cell
|/get_cell( $row, $column)> method will check the cell_id (ex. B34) for matches in this 
hashref and then if none are found it will apply any format(data manipulation) defined 
in the spreadsheet. For a match on any given cell checks will be done in this order; 
full cell_id (ex. B34), column_id (ex. B), row_id (ex.34)

B<Accepts:> a $hashref (ex. { B34 => MyTypeTinyType->plus_coercions( MyCoercion ) } )

B<Returns:> Nothing

=back

=head3 set_custom_format( $key => $value_ref )

=over

B<Definition:> The difference with this method from L<set_custom_formats
|/set_custom_formats( $hashref )> is this will only set specific key value pairs.

B<Accepts:> a $key => $value_ref list

B<Returns:> Nothing

=back

=head3 get_custom_format( $key )

=over

B<Definition:> This returns the custom format associated with that key

B<Accepts:> a $key

B<Returns:> The $value_ref (data manipulation ref) associated with $key

=back

=head3 has_custom_format( $key )

=over

B<Definition:> This checks if a custom format is registered against the $key

B<Accepts:> a $key

B<Returns:> $boolean representing existance

=back
				
=head1 SUPPORT

=over

L<github Spreadsheet::XLSX::Reader/issues|https://github.com/jandrew/Spreadsheet-XLSX-Reader/issues>

=back

=head1 TODO

=over

B<1.> Add min to max next cell

B<2.> Add read Non-Null only next cells

B<2.> Add 'fetchrow_arrayref( $row )' (as a Role?)

B<3.> Add 'set_header_row( $row )' and 'fetchrow_hashref( $row )' (as a Role?)

B<4.> Add L<Data::Walk::Graft> capabilities to 'set_custom_formats'

B<5.> Move 'get_cell( $row, $column )' into a role?

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

B<5.010> - (L<perl>)

L<version>

L<Moose>

L<MooseX::StrictConstructor>

L<MooseX::HasDefaults::RO>

L<Types::Standard>

L<Spreadsheet::XLSX::Reader::LibXML::XMLReader>

L<Spreadsheet::XLSX::Reader::LibXML::CellToColumnRow>

L<Spreadsheet::XLSX::Reader::LibXML::Cell>

=back

=head1 SEE ALSO

=over

L<Spreadsheet::XLSX>

L<Spreadsheet::ParseExcel::Worksheet>

L<Log::Shiras|https://github.com/jandrew/Log-Shiras> - to activate the debug logging

=back

=cut

#########1 Documentation End  3#########4#########5#########6#########7#########8#########9