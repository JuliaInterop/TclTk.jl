namespace eval ::_jl {
    variable SRCDIR @SRCDIR@

    proc image_exists {name {type "*"}} {
        if {[catch {image type $name} value]} {
            # No image with that name already exists.
            return 0
        } elseif {$type eq "*" || $type eq $value} {
            return 1
        } else {
            error "image \"$name\" already exists with type \"$value\", not \"$type\""
        }
    }

    # Image accessors. These save passing two arguments.
    proc image_delete name {
        ::image delete $name
    }
    proc image_inuse name {
        ::image inuse $name
    }
    proc image_width name {
        ::image width $name
    }
    proc image_height name {
        ::image width $name
    }
    proc image_type name {
        ::image type $name
    }
    proc image_size name {
        # This procedure saves calling the interpreter twice.
        list [::image width $name] [::image height $name]
    }

    proc image_create_or_config {type name args} {
        if {[catch {image type $name} value]} {
            # No image with that name already exists: create a new image.
            eval [list image create $type $name] $args
        } elseif {$type ne $value} {
            error "image \"$name\" already exists with type \"$value\", not \"$type\""
        } elseif {[::llength $args] != 0} {
            # An image with that name already exists. It must have the required type. It is
            # configured if it there are any options specified.
            eval [list $name configure] $args
        }
        return $name
    }

    proc __init__ {} {
        variable SRCDIR

        # Hide main Tk window to avoid accidentally closing the application.
        catch {wm withdraw "."}

        # Attempt to set the icon for top-level windows.
        set path [file join $SRCDIR "logo.png"]
        if {[file readable $path]} {
            set logo [image create photo "::_jl::logo" -file $path]
            catch {wm iconphoto "." -default $logo}
        }
    }
    __init__

}
