ALL: libfast
libfast: libMinsurf.so 
lib: libMinsurf.so 
-include babel.make


SOURCEC=$(IORSRCS) $(IMPLSRCS) $(SKELSRCS) $(STUBSRCS)

SOURCEH=$(IMPLHDRS) $(IORHDRS) $(STUBHDRS)
OBJSC = $(IMPLSRCS:.cxx=.o) $(IORSRCS:.c=.o) $(SKELSRCS:.cxx=.o) $(STUBSRCS:.cxx=.o)
CLEANFILES=$(STUBSRCS) $(SKELSRCS) $(IORSRCS) $(IORHDRS) $(STUBHDRS) babel.make 

CFLAGS = $(TAO_SIDL_FLAGS_CXX)


LIBS=${CC_LINKER_SLFLAG}${TAO_LIB_DIR} -L${TAO_LIB_DIR} \
        ${TAO_SIDLCLIENT_CXX_LIB} ${TAO_OPTIMIZATION_PORTS_LIB} \
	${CC_LINKER_SLFLAG}${CCASO_DIR}  -L${CCASO_DIR} -lcca 


libMinsurf.so: ${OBJSC} tao_chkopts
	@${CLINKER} -shared ${OBJSC} -o ${TAO_DIR}/lib/${PETSC_ARCH}/$@ ${LIBS}

	@sed s^@TAO_DIR@^$(TAO_DIR)^g ../cca_template | \
           sed s^@PETSC_ARCH@^$(PETSC_ARCH)^g |\
           sed s^@COMPONENT@^Minsurf.Component^g |\
           sed s^@LIBNAME@^$@^g \
	   > $(TAO_DIR)/lib/$(PETSC_ARCH)/$@.cca




include $(TAO_DIR)/bmake/tao_common

