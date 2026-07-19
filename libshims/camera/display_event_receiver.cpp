extern "C" void display_event_receiver_ctor_with_config(void*, int, int)
    __asm__("_ZN7android20DisplayEventReceiverC1ENS_16ISurfaceComposer11VsyncSourceENS1_13ConfigChangedE");

extern "C" void display_event_receiver_ctor(void* receiver, int source)
    __asm__("_ZN7android20DisplayEventReceiverC1ENS_16ISurfaceComposer11VsyncSourceE");

extern "C" void display_event_receiver_ctor(void* receiver, int source) {
  display_event_receiver_ctor_with_config(receiver, source, 0);
}
