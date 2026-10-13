find_package(Qt6 REQUIRED COMPONENTS Test)

foreach(name occurrences protocol selection)
    add_executable(test_${name} test_${name}.cpp)
    target_link_libraries(test_${name} PRIVATE calendar_core Qt6::Test)
    set_target_properties(test_${name} PROPERTIES AUTOMOC ON)
    add_test(NAME ${name} COMMAND test_${name})
    # Pin the zone so date and time results don't depend on the machine.
    set_tests_properties(${name} PROPERTIES ENVIRONMENT "TZ=Europe/Madrid")
endforeach()
