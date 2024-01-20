package App::ANSIColorUtils;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

$SPEC{show_ansi_color_table} = {
    v => 1.1,
    summary => 'Show a table of ANSI codes & colors',
    args => {
        width => {
            schema => ['str*', in=>[8, 16, 256]],
            default => 8,
            cmdline_aliases => {
                8   => {is_flag=>1, summary => 'Shortcut for --width=8'  , code => sub { $_[0]{width} = 8 }},
                16  => {is_flag=>1, summary => 'Shortcut for --width=16' , code => sub { $_[0]{width} = 16 }},
                256 => {is_flag=>1, summary => 'Shortcut for --width=256', code => sub { $_[0]{width} = 256 }},
            },
        },
    },
};
sub show_ansi_color_table {
    require Color::ANSI::Util;

    my %args = @_;

    my $width = $args{width};

    my @rows;
    for (0 .. $width - 1) {
        push @rows, {
            code => $_,
            color=>
                $_ < 8   ? sprintf("\e[%dm%s\e[0m", 30+$_, "This is ANSI color #$_") :
                $_ < 16  ? sprintf("\e[1;%dm%s\e[0m", 30+$_-8, "This is ANSI color #$_") :
                           sprintf("\e[38;5;%dm%s\e[0m", $_, "This is ANSI color #$_"),
        };
    }
    [200, "OK", \@rows];
}

$SPEC{show_colors} = {
    v => 1.1,
    summary => 'Show colors specified in argument as text with ANSI colors',
    args => {
        colors => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'color',
            schema => ['array*', of=>'str*'],
            req => 1,
            pos => 0,
            slurpy => 1,
        },
    },
};
sub show_colors {
    require Color::ANSI::Util;
    require Graphics::ColorNamesLite::All;
    #require String::Escape; # ugly: \x1b...
    require Data::Dmp;

    my $codes = $Graphics::ColorNamesLite::All::NAMES_RGB_TABLE;

    my %args = @_;

    my @colornames;
    my @colorcodes;
    if ($args{_colors_hash}) {
        @colornames  = sort keys %{ $args{_colors_hash} };
        @colorcodes = map { $args{_colors_hash}{$_} } @colornames;
    } else {
        @colornames = @colorcodes = @{ $args{colors} };
    }

    my @rows;
    for my $j (0 .. $#colornames) {
        my $colorname = $colornames[$j];
        my $colorcode = $colorcodes[$j];
        unless ($colorcode =~ /\A[0-9A-fa-f]{6}\z/) {
            $colorcode = $codes->{$colorcode}; defined $colorcode or die "Unknown color name '$colorcode'";
        }
        my $ansifg = Color::ANSI::Util::ansifg($colorcode);
        my $ansibg = Color::ANSI::Util::ansibg($colorcode);
        push @rows, {
            name => $colorname,
            rgb_code => $colorcode,
            ansi_fg_code => Data::Dmp::dmp($ansifg),
            ansi_bg_code => Data::Dmp::dmp($ansibg),
            fg =>
                $ansifg . "This is text with foreground color $colorname (#$colorcode)" . Color::ANSI::Util::ansi_reset(1) . "\n" .
                $ansifg . "\e[1m" . "This is text with foreground color $colorname (#$colorcode) + BOLD" . Color::ANSI::Util::ansi_reset(1) . "\n",
            bg => $ansibg . Color::ANSI::Util::ansifg(Color::RGB::Util::rgb_is_light($colorcode) ? "000000":"ffffff") . "This is text with background color $colorname (#$colorcode)" . Color::ANSI::Util::ansi_reset(1),
        };
    }
    [200, "OK", \@rows];
}

$SPEC{show_colors_from_scheme} = {
    v => 1.1,
    summary => 'Show colors from a Graphics::ColorNames scheme',
    args => {
        scheme => {
            schema => 'perl::colorscheme::modname*',
            req => 1,
            pos => 0,
        },
    },
};
sub show_colors_from_scheme {
    my %args = @_;
    my $mod = "Graphics::ColorNames::$args{scheme}";
    (my $modpm = "$mod.pm") =~ s!::!/!g;
    require $modpm;

    my $table = $mod->NamesRgbTable;
    show_colors(colors => [sort keys %$table]);
}

$SPEC{show_colors_from_theme} = {
    v => 1.1,
    summary => 'Show colors from a ColorTheme scheme',
    args => {
        theme => {
            schema => 'perl::colortheme::modname_with_optional_args*',
            req => 1,
            pos => 0,
        },
    },
    links => [
        {url=>'prog:show-color-theme-swatch'},
    ],
};
sub show_colors_from_theme {
    require Module::Load::Util;

    my %args = @_;
    my $mod = $args{theme}; $mod = "ColorTheme::$mod" unless $mod =~ /^ColorTheme::/;
    my $theme = Module::Load::Util::instantiate_class_with_optional_args($mod);

    my @item_names = $theme->list_items;
    my %colors;
    for my $item ($theme->list_items) {
        my $k = $item;
        my $v = $theme->get_item_color($item);
        if (ref $v) {
            $k = "$k (hash or coderef)";
            $v = "ffffff";
        }
        $colors{$k} = $v;
    }
    show_colors(_colors_hash =>\%colors);
}

$SPEC{show_assigned_rgb_colors} = {
    v => 1.1,
    summary => 'Take arguments, pass them through assign_rgb_color(), show the results',
    description => <<'_',

`assign_rgb_color()` from <pm:Color::RGB::Util> takes a string, produce SHA1
digest from it, then take 24bit from the digest as the assigned color.

_
    args => {
        strings => {
            schema => ['array*', of=>'str*'],
            req => 1,
            pos => 0,
            greedy => 1,
        },
        tone => {
            schema => ['str*', in=>['light', 'dark']],
            cmdline_aliases => {
                light => {is_flag=>1, summary=>'Shortcut for --tone=light', code=>sub { $_[0]{tone} = 'light' }},
                dark  => {is_flag=>1, summary=>'Shortcut for --tone=dark' , code=>sub { $_[0]{tone} = 'dark'  }},
            },
        },
    },
};
sub show_assigned_rgb_colors {
    require Color::ANSI::Util;
    require Color::RGB::Util;

    my %args = @_;

    my $tone = $args{tone} // '';
    my $strings = $args{strings};

    my @rows;
    for (0 .. $#{ $strings }) {
        my $str = $strings->[$_];
        my $rgb =
            $tone eq 'light' ? Color::RGB::Util::assign_rgb_light_color($str) :
            $tone eq 'dark'  ? Color::RGB::Util::assign_rgb_dark_color($str) :
            Color::RGB::Util::assign_rgb_color($str);
        push @rows, {
            number => $_+1,
            string => $str,
            color  => sprintf("%s%s\e[0m", Color::ANSI::Util::ansifg($rgb), "'$str' is assigned color #$rgb"),
            "light?" => Color::RGB::Util::rgb_is_light($rgb),
        };
    }
    [200, "OK", \@rows, {"table.fields" => [qw/number string color light?/]}];
}

$SPEC{show_rand_rgb_colors} = {
    v => 1.1,
    summary => 'Produce N random RGB colors using rand_rgb_colors() and show the results',
    args => {
        n => {
            schema => 'posint*',
            req => 1,
            pos => 0,
        },
        light_color => {
            schema => 'bool',
            default => 1,
            cmdline_aliases => {
                light_or_dark_color => {is_flag=>1, code=>sub { $_[0]{light_color} = undef }},
                dark_color          => {is_flag=>1, code=>sub { $_[0]{light_color} = 0 }},
            },
        },
    },
};
sub show_rand_rgb_colors {
    require Color::RGB::Util;

    my %args = @_;
    my $n = $args{n};

    my @colors = Color::RGB::Util::rand_rgb_colors({
        light_color => $args{light_color},
    }, $n);
    my @rows;
    for (1 .. $n) {
        my $color = $colors[$_-1];
        push @rows, {
            number => $_,
            color  => sprintf("%s      %s      \e[0m",
                              Color::ANSI::Util::ansifg(Color::RGB::Util::rgb_is_dark($color) ? "ffffff" : "000000").
                                    Color::ANSI::Util::ansibg($color),
                              "#".$color),
        };
    }
    [200, "OK", \@rows, {"table.fields" => [qw/number color/]}];
}

$SPEC{show_text_using_color_gradation} = {
    v => 1.1,
    summary => 'Print text using gradation between two colors',
    description => <<'_',

This can be used to demonstrate 24bit color support in terminal emulators.

_
    args => {
        text => {
            schema => ['str*', min_len=>1],
            pos => 0,
            description => <<'_',

If unspecified, will show a bar of '=' across the terminal.

_
        },
        color1 => {
            schema => 'color::rgb24*',
            default => 'ffff00',
        },
        color2 => {
            schema => 'color::rgb24*',
            default => '0000ff',
        },
    },
    examples => [
        {
            args => {color1=>'blue', color2=>'pink', text=>'Hello, world'},
            test => 0,
            'x.doc_show_result'=>0,
        },
    ],
};
sub show_text_using_color_gradation {
    require Color::ANSI::Util;
    require Color::RGB::Util;
    require Term::Size;

    my %args = @_;

    my $color1 = $args{color1};
    my $color2 = $args{color2};

    my $text = $args{text};
    $text //= do {
        my $width = $ENV{COLUMNS} // (Term::Size::chars(*STDOUT{IO}))[0] // 80;
        "X" x $width;
    };
    my $len = length $text;
    my $i = 0;
    for my $c (split //, $text) {
        $i++;
        my $color = Color::RGB::Util::mix_2_rgb_colors($color1, $color2, $i/$len);
        print Color::ANSI::Util::ansifg($color), $c;
    }
    print "\n\e[0m";

    [200];
}

1;
#ABSTRACT: Utilities related to ANSI color

=head1 DESCRIPTION

This distributions provides the following command-line utilities:

# INSERT_EXECS_LIST


=head1 SEE ALSO

L<App::RGBColorUtils>

L<App::GraphicsColorNamesUtils>

L<App::ColorThemeUtils>

=cut
