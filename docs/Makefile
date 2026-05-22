SOURCES = \
    make.jl \
    src/callbacks.md \
    src/develop.md \
    src/dialogs.md \
    src/images.md \
    src/index.md \
    src/interpreters.md \
    src/lists.md \
    src/objects.md \
    src/public.md \
    src/variables.md \
    src/widgets.md \
    src/winfo.md

default: build/index.html

clean:
	rm -f *~ */*~ */*/*~

force:
	julia --color=yes make.jl

build/index.html: $(SOURCES)
	make force

.PHOONY: default clean force
