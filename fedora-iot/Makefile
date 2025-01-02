IGNITION = config.ign box01.ign

PODMAN := podman run -i --rm quay.io/coreos/butane --pretty --strict

.PHONY: all
all: $(IGNITION)

config.ign: config.bu
box01.ign: box01.bu

%.ign:
	$(PODMAN) < $< > $@

.PHONY: clean
clean:
	rm $(IGNITION)
