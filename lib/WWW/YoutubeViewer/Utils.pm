package WWW::YoutubeViewer::Utils;

use utf8;
use 5.014;
use warnings;

no if $] >= 5.018, warnings => 'experimental::smartmatch';

=head1 NAME

WWW::YoutubeViewer::Utils - Various utils.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

    use WWW::YoutubeViewer::Utils;

    my $yv_utils = WWW::YoutubeViewer::Utils->new(%opts);

    print $yv_utils->format_time(3600);

=head1 SUBROUTINES/METHODS

=head2 new(%opts)

Options:

=over 4

=item thousand_separator => ""

Character used as thousand separator.

=item months => []

Month names for I<format_date()>

=item youtube_url_format => ""

A youtube URL format for sprintf(format, videoID).

=back

=cut

sub new {
    my ($class, %opts) = @_;

    my $self = bless {
                      thousand_separator => q{,},
                      youtube_url_format => 'https://www.youtube.com/watch?v=%s',
                     }, $class;

    $self->{months} = [
        qw(
          Jan Feb Mar
          Apr May Jun
          Jul Aug Sep
          Oct Nov Dec
          )
    ];

    foreach my $key (keys %{$self}) {
        $self->{$key} = delete $opts{$key}
          if exists $opts{$key};
    }

    foreach my $invalid_key (keys %opts) {
        warn "Invalid key: '${invalid_key}'";
    }

    return $self;
}

=head2 video_extension($type)

Returns the video extension format from a video type.

From a string like 'video/webm;+codecs="vp9"', it returns 'webm'.

=cut

sub video_extension {
    my ($self, $type) = @_;
        $type =~ /\bflv\b/i      ? q{flv}
      : $type =~ /\bwebm\b/i     ? q{webm}
      : $type =~ /\b3gpp?\b/i    ? q{3gp}
      : $type =~ m{^video/(\w+)} ? $1
      :                            q{mp4};
}

=head2 format_time($sec)

Returns time from seconds.

=cut

sub format_time {
    my ($self, $sec) = @_;
    $sec >= 3600
      ? join q{:}, map { sprintf '%02d', $_ } $sec / 3600 % 24, $sec / 60 % 60, $sec % 60
      : join q{:}, map { sprintf '%02d', $_ } $sec / 60 % 60, $sec % 60;
}

=head2 format_duration($duration)

Return time (01:20:10) from duration (PT1H20M10S).

=cut

# PT5M3S     -> 05:03
# PT1H20M10S -> 01:20:10
# PT16S      -> 00:16

sub format_duration {
    my ($self, $duration) = @_;

    $duration // return 0;
    my ($hour, $min, $sec) = (0, 0, 0);

    $hour = $1 if ($duration =~ /(\d+)H/);
    $min  = $1 if ($duration =~ /(\d+)M/);
    $sec  = $1 if ($duration =~ /(\d+)S/);

    $hour * 60 * 60 + $min * 60 + $sec;
}

=head2 format_date($date)

Return string "04 May 2010" from "2010-05-04T00:25:55.000Z"

=cut

sub format_date {
    my ($self, $date) = @_;

    # 2010-05-04T00:25:55.000Z
    # to: 04 May 2010

    $date =~ s{^
    (?<year>\d{4})
           -
    (?<month>\d{2})
           -
    (?<day>\d{2})
        .*
    }
    {$+{day} $self->{months}[$+{month} - 1] $+{year}}x;

    return $date;
}

=head2 has_entries($request)

Returns true if a given request has entries.

=cut

sub has_entries {
    my ($self, $req) = @_;
    !!$req->{results}{pageInfo}{totalResults};
}

=head2 normalize_video_title($title)

Replace file-unsafe characters and trim spaces.

=cut

sub normalize_video_title {
    my ($self, $title) = @_;

    if ($^O ~~ [qw(linux freebsd openbsd)]) {
        $title =~ tr{/}{%};
    }
    else {
        $title =~ tr{:"*/?\\|}{;'+%$%%};    # "
    }

    join(q{ }, split(q{ }, $title));
}

=head2 format_text($streaming=HASH, $video_info=HASH, $text=STRING, $escape=BOOL)

Format a text with information from streaming and video info.

=cut

sub format_text {
    my ($self, $streaming, $info, $text, $quotemeta) = @_;

    my %special_tokens = (
        ID          => sub { $self->get_video_id($info) },
        AUTHOR      => sub { $self->get_channel_title($info) },
        CHANNELID   => sub { $self->get_channel_id($info) },
        DEFINITION  => sub { $self->get_definition($info) },
        DIMENSION   => sub { $self->get_dimension($info) },
        VIEWS       => sub { $self->get_views($info) },
        LIKES       => sub { $self->get_likes($info) },
        DISLIKES    => sub { $self->get_dislikes($info) },
        COMMENTS    => sub { $self->get_comments($info) },
        DURATION    => sub { $self->get_duration($info) },
        TIME        => sub { $self->format_time($self->get_duration($info)) },
        TITLE       => sub { $self->get_title($info) },
        FTITLE      => sub { $self->normalize_video_title($self->get_title($info)) },
        CAPTION     => sub { $self->get_caption($info) },
        DESCRIPTION => sub { $self->get_description($info) },

        RESOLUTION => sub {
            $streaming->{resolution} =~ /^\d+\z/
              ? $streaming->{resolution} . 'p'
              : $streaming->{resolution};
        },

        ITAG   => sub { $streaming->{streaming}{itag} },
        SIZE   => sub { $streaming->{streaming}{size} },
        SUB    => sub { $streaming->{srt_file} },
        VIDEO  => sub { $streaming->{streaming}{url} },
        FORMAT => sub { $self->video_extension($streaming->{streaming}{type}) },

        AUDIO => sub {
            ref($streaming->{streaming}{__AUDIO__}) eq 'HASH'
              ? $streaming->{streaming}{__AUDIO__}{url}
              : q{};
        },

        AOV => sub {
            ref($streaming->{streaming}{__AUDIO__}) eq 'HASH'
              ? $streaming->{streaming}{__AUDIO__}{url}
              : $streaming->{streaming}{url};
        },

        URL => sub { sprintf($self->{youtube_url_format}, $self->get_video_id($info)) },
                         );

    my $tokens_re = do {
        local $" = '|';
        qr/\*(@{[map {quotemeta} keys %special_tokens]})\*/;
    };

    my %special_escapes = (
                           a => "\a",
                           b => "\b",
                           e => "\e",
                           f => "\f",
                           n => "\n",
                           r => "\r",
                           t => "\t",
                          );

    my $escapes_re = do {
        local $" = q{};
        qr/\\([@{[keys %special_escapes]}])/;
    };

    $text =~ s/$escapes_re/$special_escapes{$1}/g;

    $quotemeta
      ? $text =~ s/$tokens_re/\Q${\$special_tokens{$1}()}\E/gr
      : $text =~ s/$tokens_re/${\$special_tokens{$1}()}/gr;
}

=head2 set_thousands($num)

Return the number with thousand separators.

=cut

sub set_thousands {    # ugly, but fast
    my ($self, $n) = @_;

    return 0 unless $n;
    length($n) > 3 or return $n;

    my $l = length($n) - 3;
    my $i = ($l - 1) % 3 + 1;
    my $x = substr($n, 0, $i) . $self->{thousand_separator};

    while ($i < $l) {
        $x .= substr($n, $i, 3) . $self->{thousand_separator};
        $i += 3;
    }

    return $x . substr($n, $i);
}

=head2 get_video_id($info)

Get videoID.

=cut

sub get_video_id {
    my ($self, $info) = @_;

    ref($info->{id}) eq 'HASH'                        ? $info->{id}{videoId}
      : exists($info->{snippet}{resourceId}{videoId}) ? $info->{snippet}{resourceId}{videoId}
      : exists($info->{contentDetails}{videoId})      ? $info->{contentDetails}{videoId}
      :                                                 $info->{id};
}

sub get_playlist_id {
    my ($self, $info) = @_;
    ref($info->{id}) eq 'HASH'
      ? $info->{id}{playlistId}
      : $info->{id};
}

=head2 get_description($info)

Get description.

=cut

sub get_description {
    my ($self, $info) = @_;
    $info->{snippet}{description} || 'No description available...';
}

=head2 get_title($info)

Get title.

=cut

sub get_title {
    my ($self, $info) = @_;
    $info->{snippet}{title} || $self->get_video_id($info);
}

=head2 get_thumbnail_url($info;$type='default')

Get thumbnail URL.

=cut

sub get_thumbnail_url {
    my ($self, $info, $type) = @_;
    $info->{snippet}{thumbnails}{$type}{url} // $info->{snippet}{thumbnails}{default}{url};
}

sub get_channel_title {
    my ($self, $info) = @_;
    $info->{snippet}{channelTitle} || $self->get_channel_id($info);
}

sub get_channel_id {
    my ($self, $info) = @_;
    $info->{snippet}{channelId};
}

sub get_publication_date {
    my ($self, $info) = @_;
    $self->format_date($info->{snippet}{publishedAt});
}

sub get_duration {
    my ($self, $info) = @_;
    $self->format_duration($info->{contentDetails}{duration});
}

sub get_definition {
    my ($self, $info) = @_;
    uc($info->{contentDetails}{definition});
}

sub get_dimension {
    my ($self, $info) = @_;
    uc($info->{contentDetails}{dimension});
}

sub get_caption {
    my ($self, $info) = @_;
    $info->{contentDetails}{caption};
}

sub get_views {
    my ($self, $info) = @_;
    $info->{statistics}{viewCount};
}

sub get_likes {
    my ($self, $info) = @_;
    $info->{statistics}{likeCount};
}

sub get_dislikes {
    my ($self, $info) = @_;
    $info->{statistics}{dislikeCount};
}

sub get_comments {
    my ($self, $info) = @_;
    $info->{statistics}{commentCount};
}

{
    no strict 'refs';
    foreach my $pair ([playlist => {'youtube#playlist' => 1}],
                      [channel => {'youtube#channel' => 1}],
                      [video   => {'youtube#video'   => 1, 'youtube#playlistItem' => 1}],
      ) {

        *{__PACKAGE__ . '::' . 'is_' . $pair->[0]} = sub {
            my ($self, $item) = @_;

            if (ref($item->{id}) eq 'HASH') {
                if (exists $pair->[1]{$item->{id}{kind}}) {
                    return 1;
                }
            }
            elsif (exists $item->{kind}) {
                if (exists $pair->[1]{$item->{kind}}) {
                    return 1;
                }
            }

            return;
        };

    }
}

sub period_to_date {
    my ($self, $amount, $period) = @_;

    state $day   = 60 * 60 * 24;
    state $month = $day * 30.4368;
    state $year  = $day * 365.242;

    my $time = $amount * (
                            $period =~ /^d/i ? $day
                          : $period =~ /^m/i ? $month
                          : $period =~ /^y/i ? $year
                          : 0
                         );

    my $now  = time;
    my @time = gmtime($now - $time);
    join('-', $time[5] + 1900, sprintf('%02d', $time[4] + 1), sprintf('%02d', $time[3])) . 'T'
      . join(':', sprintf('%02d', $time[2]), sprintf('%02d', $time[1]), sprintf('%02d', $time[0])) . 'Z';
}

=head1 AUTHOR

Trizen, C<< <trizenx at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::YoutubeViewer::Utils


=head1 LICENSE AND COPYRIGHT

Copyright 2012-2015 Trizen.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1;    # End of WWW::YoutubeViewer::Utils