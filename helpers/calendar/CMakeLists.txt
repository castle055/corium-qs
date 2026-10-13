find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui)
find_package(KF6CalendarCore REQUIRED)

# Everything that doesn't talk to Akonadi, so it can be unit tested.
add_library(calendar_core STATIC
    src/occurrences.cpp
    src/protocol.cpp
    src/selection.cpp
)
target_include_directories(calendar_core PUBLIC src)
target_link_libraries(calendar_core PUBLIC Qt6::Core Qt6::Gui KF6::CalendarCore)
target_compile_options(calendar_core PRIVATE -Wall -Wextra)

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

# Akonadi's CMake packages need extra-cmake-modules (ECM) to be installed.
find_package(KF6Config)
find_package(KPim6Akonadi)
find_package(KPim6AkonadiCalendar)

if(NOT KF6Config_FOUND OR NOT KPim6Akonadi_FOUND OR NOT KPim6AkonadiCalendar_FOUND)
    message(WARNING "Akonadi development files not found (is extra-cmake-modules installed?). "
                    "Building only the calendar tests, not corium-calendar.")
    return()
endif()

add_executable(corium-calendar
    src/akonadisource.cpp
    src/main.cpp
)
target_link_libraries(corium-calendar PRIVATE
    calendar_core
    KF6::ConfigCore
    KPim6::AkonadiCore
    KPim6::AkonadiCalendar
)
target_compile_options(corium-calendar PRIVATE -Wall -Wextra)
set_target_properties(corium-calendar PROPERTIES AUTOMOC ON)
