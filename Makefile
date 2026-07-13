# **************************************************************************** #
#                            Makefile for ircserv                              #
# **************************************************************************** #

# ------------------------------- Configuration ------------------------------ #

NAME     := ircserv
INC      := inc
OBJ_ROOT := obj

SRCDIR := src/
CMDDIR := $(SRCDIR)cmd/
SRC :=	$(SRCDIR)main.cpp \
		$(SRCDIR)Client.cpp \
		$(SRCDIR)CommandHandler.cpp \
		$(SRCDIR)Server.cpp \
		$(SRCDIR)Utils.cpp \
		$(SRCDIR)Channel.cpp \
		$(CMDDIR)invite.cpp \
		$(CMDDIR)join.cpp \
		$(CMDDIR)kick.cpp \
		$(CMDDIR)mode.cpp \
		$(CMDDIR)part.cpp \
		$(CMDDIR)privmsg.cpp \
		$(CMDDIR)quit.cpp \
		$(CMDDIR)topic.cpp

# ------------------------------ System Detection ---------------------------- #

UNAME := $(shell uname -s)

ifeq ($(UNAME), Darwin)
	DETECTED_CXX := c++
	NUMPROC := $(shell sysctl -n hw.ncpu)
else ifeq ($(UNAME), Linux)
	DETECTED_CXX := $(shell \
		for bin in clang++-21 clang++-20 clang++-19 clang++-18 clang++-17 clang++ g++-14 g++-13 g++-12 g++ ; do \
			if command -v $$bin >/dev/null 2>&1; then echo $$bin; break; fi; \
		done \
	)
	NUMPROC := $(shell grep -c ^processor /proc/cpuinfo)
else
	$(error Unsupported OS: $(UNAME))
endif

# Respect an explicit `make CXX=...` / CI override; autodetect otherwise
ifeq ($(origin CXX),default)
	CXX := $(DETECTED_CXX)
endif

COMPILER_VERSION := $(shell $(CXX) --version | head -n 1)

# ------------------------------ Compilation Flags --------------------------- #

STDFLAG   := -std=c++98
BASEFLAGS := -Wall -Wextra -Werror $(STDFLAG) -I$(INC)
DEPFLAGS   = -MMD -MP
LDFLAGS   :=

RELEASE_FLAGS := -O2
DEBUG_FLAGS   := -g3 -O0 -DDEBUG
ASAN_FLAGS    := -g3 -O1 -fsanitize=address,undefined -fno-omit-frame-pointer
COVER_FLAGS   := -g -O0 -fprofile-instr-generate -fcoverage-mapping

# --------------------------- Objects per variant ----------------------------- #

OBJ_RELEASE := $(SRC:%.cpp=$(OBJ_ROOT)/release/%.o)
OBJ_DEBUG   := $(SRC:%.cpp=$(OBJ_ROOT)/debug/%.o)
OBJ_ASAN    := $(SRC:%.cpp=$(OBJ_ROOT)/asan/%.o)
OBJ_COVER   := $(SRC:%.cpp=$(OBJ_ROOT)/cover/%.o)
DEPS        := $(OBJ_RELEASE:.o=.d) $(OBJ_DEBUG:.o=.d) $(OBJ_ASAN:.o=.d) $(OBJ_COVER:.o=.d)

BINARIES := $(NAME) $(NAME)-debug $(NAME)-asan $(NAME)-cover

# ------------------------------- Variables ---------------------------------- #

RM  := rm -fr
OBS := $(NAME).dSYM .DS_Store output.log $(NAME).profdata $(NAME).profraw coverage \
	   coverage.txt coverage.info out

# --------------------------- Targets & Rules --------------------------------- #

PHONY += all
all: $(NAME) banner ## build the release binary (default)

$(NAME): $(OBJ_RELEASE)
	@$(CXX) $(BASEFLAGS) $(RELEASE_FLAGS) $(LDFLAGS) $^ -o $@
	@echo "$(L_BLUE)  [info]:  $(L_GREEN)linked $(L_MAGENTA)$@$(RESET)"

$(NAME)-debug: $(OBJ_DEBUG)
	@$(CXX) $(BASEFLAGS) $(DEBUG_FLAGS) $(LDFLAGS) $^ -o $@
	@echo "$(L_BLUE)  [info]:  $(L_GREEN)linked $(L_MAGENTA)$@$(RESET)"

$(NAME)-asan: $(OBJ_ASAN)
	@$(CXX) $(BASEFLAGS) $(ASAN_FLAGS) $(LDFLAGS) $^ -o $@
	@echo "$(L_BLUE)  [info]:  $(L_GREEN)linked $(L_MAGENTA)$@$(RESET)"

$(NAME)-cover: $(OBJ_COVER)
	@$(CXX) $(BASEFLAGS) $(COVER_FLAGS) $(LDFLAGS) $^ -o $@
	@echo "$(L_BLUE)  [info]:  $(L_GREEN)linked $(L_MAGENTA)$@$(RESET)"

PHONY += debug asan
debug: $(NAME)-debug ## build with -g3 -O0 (binary: ircserv-debug)
asan: $(NAME)-asan ## build with address+UB sanitizers (binary: ircserv-asan)

$(OBJ_ROOT)/release/%.o: %.cpp
	@mkdir -p $(dir $@)
	@printf "$(L_BLUE)  [info]:  $(L_GREEN)%-30s -> $(L_BLUE)%s$(RESET)\n" "$<" "$@"
	@$(CXX) $(BASEFLAGS) $(RELEASE_FLAGS) $(DEPFLAGS) -c $< -o $@

$(OBJ_ROOT)/debug/%.o: %.cpp
	@mkdir -p $(dir $@)
	@printf "$(L_BLUE)  [info]:  $(L_GREEN)%-30s -> $(L_BLUE)%s$(RESET)\n" "$<" "$@"
	@$(CXX) $(BASEFLAGS) $(DEBUG_FLAGS) $(DEPFLAGS) -c $< -o $@

$(OBJ_ROOT)/asan/%.o: %.cpp
	@mkdir -p $(dir $@)
	@printf "$(L_BLUE)  [info]:  $(L_GREEN)%-30s -> $(L_BLUE)%s$(RESET)\n" "$<" "$@"
	@$(CXX) $(BASEFLAGS) $(ASAN_FLAGS) $(DEPFLAGS) -c $< -o $@

$(OBJ_ROOT)/cover/%.o: %.cpp
	@mkdir -p $(dir $@)
	@printf "$(L_BLUE)  [info]:  $(L_GREEN)%-30s -> $(L_BLUE)%s$(RESET)\n" "$<" "$@"
	@$(CXX) $(BASEFLAGS) $(COVER_FLAGS) $(DEPFLAGS) -c $< -o $@

# wildcard-guarded: an -include of a *nonexistent* .d file makes GNU Make try to
# build it as a target, which falls through to .DEFAULT and recurses via $(MAKE).
-include $(wildcard $(DEPS))

PHONY += clean
clean: ## remove all object files
	@$(RM) $(OBJ_ROOT)

PHONY += fclean
fclean: clean ## clean + remove binaries and generated junk
	@$(RM) $(BINARIES) $(OBS)

PHONY += re
re: fclean all ## fclean then rebuild

PHONY += build
build: ## parallel release build using all cores
	@echo "$(L_BLUE)  [info]:  $(L_GREEN)Starting parallel build using '$(NUMPROC)' threads...$(RESET)"
	@$(MAKE) -s -j$(NUMPROC) all

# --------------------------------- Tests ------------------------------------- #

PHONY += test
test: $(NAME) ## build release and run the integration test suite
	@bash tests/run_tests.sh ./$(NAME)

PHONY += test-asan
test-asan: $(NAME)-asan ## run the test suite against the sanitized binary
	@ASAN_OPTIONS=detect_leaks=1 IRC_TIMEOUT=8 bash tests/run_tests.sh ./$(NAME)-asan

PHONY += valgrind
valgrind: $(NAME)-debug ## run the test suite under valgrind (leak check)
	@IRC_WRAPPER="valgrind --leak-check=full --show-leak-kinds=definite --errors-for-leak-kinds=definite --error-exitcode=42" \
		IRC_TIMEOUT=10 bash tests/run_tests.sh ./$(NAME)-debug

# ------------------------------- Coverage ------------------------------------ #

PHONY += coverage
coverage: ## build instrumented binary, run test suite, report coverage (clang only)
ifeq (,$(findstring clang,$(CXX)))
	@echo >&2 "$(L_RED)[Error]$(RESET): coverage requires clang (current CXX: $(CXX)). Try 'make coverage CXX=clang++'."
	@exit 1
else
	@$(MAKE) -s $(NAME)-cover
	@mkdir -p $(OBJ_ROOT)/cover
	@LLVM_PROFILE_FILE="$(OBJ_ROOT)/cover/%p.profraw" bash tests/run_tests.sh ./$(NAME)-cover
	@llvm-profdata merge -sparse $(OBJ_ROOT)/cover/*.profraw -o $(NAME).profdata
	@llvm-cov report ./$(NAME)-cover -instr-profile=$(NAME).profdata
	@llvm-cov show ./$(NAME)-cover -instr-profile=$(NAME).profdata -format=html -output-dir=coverage
	@echo "HTML report available in ./coverage/index.html"
endif

# ---------------------------- Static Analysis -------------------------------- #

TIDY_FLAGS =	'clang-analyzer-*,\
				bugprone-*,\
				performance-*,\
				misc-const-correctness,\
				misc-misplaced-const,\
				cppcoreguidelines-avoid-const-or-ref-data-members,\
				readability-avoid-const-params-in-decls,\
				readability-const-return-type,\
				readability-make-member-function-const,\
				llvm-include-order,\
				cppcoreguidelines-init-variables,\
				llvmlibc-inline-function-decl,\
				hicpp-braces-around-statements,\
				readability-braces-around-statements,\
				google-runtime-int,\
				readability-implicit-bool-conversion,\
				readability-isolate-declaration,\
				readability-redundant-string-init,\
				cppcoreguidelines-special-member-functions,\
				hicpp-special-member-functions,\
				readability-convert-member-functions-to-static,\
				google-explicit-constructor,\
				hicpp-explicit-conversions,\
				hicpp-signed-bitwise,\
				hicpp-deprecated-headers,\
				modernize-deprecated-headers,\
				misc-use-anonymous-namespace,\
				misc-definitions-in-headers'

CLANG_TIDY := $(firstword $(foreach v,$(shell seq 21 -1 15),$(if $(shell command -v clang-tidy-$(v)),clang-tidy-$(v))))
ifeq ($(CLANG_TIDY),)
CLANG_TIDY := clang-tidy
endif

PHONY += tidy
tidy: ## run clang-tidy on the project (advisory)
	@$(CLANG_TIDY) $(SRC) \
	--checks=$(TIDY_FLAGS) \
	--header-filter='$(INC)/.*' \
	--system-headers=false \
	--quiet \
	-- $(BASEFLAGS)
	@echo "✅ tidy check complete"

PHONY += cppcheck
cppcheck: ## run cppcheck static analysis (CI gate)
	@cppcheck --std=c++03 --language=c++ \
		--enable=warning,performance,portability \
		--inline-suppr --error-exitcode=1 \
		--suppress=missingIncludeSystem \
		-I$(INC) $(SRCDIR)
	@echo "✅ cppcheck complete"

PHONY += check
check: cppcheck tidy ## run all static analysis

SCAN_BUILD := $(firstword $(foreach v,$(shell seq 21 -1 15),$(if $(shell command -v scan-build-$(v)),scan-build-$(v))))
ifeq ($(SCAN_BUILD),)
SCAN_BUILD := scan-build
endif

PHONY += scan
scan: fclean ## scan-build static analysis
	@echo "🔍 Running scan-build ($(SCAN_BUILD))..."
	@CXX=$(CXX) $(SCAN_BUILD) \
		-enable-checker alpha \
		-enable-checker security -enable-checker unix -enable-checker core \
		-enable-checker cplusplus -enable-checker deadcode -enable-checker nullability \
		-analyzer-config aggressive-binary-operation-simplification=true \
		-v $(MAKE)
	@echo "✅ Scan-build analysis complete"

# ------------------------------- Cosmetics ------------------------------------ #

PHONY += banner
SHIFT = $(eval O=$(shell echo $$((($(O)%15)+1))))
banner: ## prints the ircserv banner for the makefile
	@echo " $(C)$(O)$(L)+----------------------------------------+$(RESET)"
	@echo " $(C)$(O)$(L)|  _                                     |";
	$(SHIFT)
	@echo " $(C)$(O)$(L)| (_) _ __  ___  ___   ___  _ __ __   __ |";
	@echo " $(C)$(O)$(L)| | || '__|/ __|/ __| / _ \| '__|\ \ / / |";
	$(SHIFT)
	@echo " $(C)$(O)$(L)| | || |  | (__ \__ \|  __/| |    \ V /  |";
	@echo " $(C)$(O)$(L)| |_||_|   \___||___/ \___||_|     \_/   |";
	@echo " $(C)$(O)$(L)+----------------------------------------+$(RESET)"

PHONY += info
info: ## prints project based info
	@echo "$(L_CYAN)# ------------------------- Build Info -------------------------- #$(RESET)"
	@echo "$(L_GREEN)NAME        $(RESET): $(L_MAGENTA)$(NAME)$(RESET)"
	@echo "$(L_GREEN)UNAME       $(RESET): $(L_MAGENTA)$(UNAME)$(RESET)"
	@echo "$(L_GREEN)NUMPROC     $(RESET): $(L_MAGENTA)$(NUMPROC)$(RESET)"
	@echo "$(L_GREEN)CXX         $(RESET): $(L_MAGENTA)$(COMPILER_VERSION)$(RESET)"
	@echo "$(L_GREEN)STANDARD    $(RESET): $(L_MAGENTA)$(STDFLAG)$(RESET)"
	@echo "$(L_GREEN)BASEFLAGS   $(RESET): $(L_MAGENTA)$(BASEFLAGS)$(RESET)"
	@echo "$(L_GREEN)RELEASE     $(RESET): $(L_MAGENTA)$(RELEASE_FLAGS)$(RESET)"
	@echo "$(L_GREEN)DEBUG       $(RESET): $(L_MAGENTA)$(DEBUG_FLAGS)$(RESET)"
	@echo "$(L_GREEN)ASAN        $(RESET): $(L_MAGENTA)$(ASAN_FLAGS)$(RESET)"
	@echo "$(L_GREEN)LDFLAGS     $(RESET): $(L_MAGENTA)$(LDFLAGS)$(RESET)"
	@echo "$(L_GREEN)SRC         $(RESET):"
	@echo "$(L_BLUE)$(SRC)$(RESET)"
	@echo "$(L_CYAN)# --------------------------------------------------------------- #$(RESET)"

PHONY += help
help: ## prints a list of the possible commands
	@echo "$(L_CYAN)# ------------------------- Help Menu -------------------------- #$(RESET)"
	@printf "$(L_MAGENTA)%-15s$(RESET) $(L_BLUE)make [target] ...$(RESET)\n\n" "Usage:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(L_GREEN)%-15s$(L_BLUE) %s$(RESET)\n", $$1, $$2}'
	@printf "\n$(L_GREEN)NOTE:$(L_BLUE) Use 'make debug' or 'make asan' for instrumented builds.$(RESET)\n"
	@printf "\n%-35s ${L_BLUE}This MAKE has Super Cow Powers.${RESET}\n"
	@echo "$(L_CYAN)# --------------------------------------------------------------- #$(RESET)"

.DEFAULT:
	@echo >&2 "${L_RED}[Error]${RESET}: ${L_BLUE}\tUnknown target '${L_RED}$@${L_BLUE}'.${RESET}"
	@${MAKE} -s help

# ----------------------------- Phony Targets -------------------------------- #

.PHONY: $(PHONY)

# ---------------------------- Color Definitions ----------------------------- #

GB         := \033[42m
RESET      := \033[0m
RED        := \033[0;31m
WHITE      := \033[0;97m
BLUE       := \033[0;36m
GRAY       := \033[0;90m
CYAN       := \033[0;36m
BLACK      := \033[0;30m
GREEN      := \033[0;32m
YELLOW     := \033[0;33m
MAGENTA    := \033[0;35m
L_RED      := \033[0;91m
L_GRAY     := \033[0;37m
L_BLUE     := \033[0;94m
L_CYAN     := \033[0;96m
L_GREEN    := \033[0;92m
L_YELLOW   := \033[0;93m
L_MAGENTA  := \033[0;95m
C          := \033[38;5;
O          := 72
L          := m
