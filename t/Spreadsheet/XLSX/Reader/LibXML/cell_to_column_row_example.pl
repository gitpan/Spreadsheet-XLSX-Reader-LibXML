#!perl
package MyPackage;
use Moose;
use lib '../../../../lib';
with 'Spreadsheet::XLSX::Reader::CellToColumnRow';

sub set_error{}
sub get_log_space{}
	
sub my_method{
	my ( $self, $cell ) = @_;
	my ($column, $row ) = $self->parse_column_row( $cell );
	print $self->error if( !defined $column or !defined $row );
	return ($column, $row );
}

package main;

my $parser = MyPackage->new( count_from_zero => 0 );
print '(' . join( ', ', $parser->my_method( 'B2' ) ) . ")\n";