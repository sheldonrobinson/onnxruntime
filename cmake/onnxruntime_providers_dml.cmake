# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

  file(GLOB_RECURSE onnxruntime_providers_dml_ep_srcs CONFIGURE_DEPENDS
    "${ONNXRUNTIME_ROOT}/core/providers/dml/*.h"
    "${ONNXRUNTIME_ROOT}/core/providers/dml/*.cpp"
    "${ONNXRUNTIME_ROOT}/core/providers/dml/*.cc"
  )
  
  if(NOT onnxruntime_BUILD_SHARED_LIB)
	file(GLOB_RECURSE
         onnxruntime_providers_dml_shared_lib_srcs CONFIGURE_DEPENDS
         "${ONNXRUNTIME_ROOT}/core/providers/shared_library/*.h"
         "${ONNXRUNTIME_ROOT}/core/providers/shared_library/*.cc"
    )
	set(onnxruntime_providers_dml_srcs ${onnxruntime_providers_dml_ep_srcs}
                                       ${onnxruntime_providers_dml_shared_lib_srcs})

    source_group(TREE ${ONNXRUNTIME_ROOT}/core FILES ${onnxruntime_providers_dml_srcs})
	onnxruntime_add_shared_library_module(onnxruntime_providers_dml ${onnxruntime_providers_dml_srcs})
	onnxruntime_add_include_to_target(onnxruntime_providers_dml ${ONNXRUNTIME_PROVIDERS_SHARED} ${ABSEIL_LIBS} ${GSL_TARGET} onnx
                                                                onnxruntime_common Boost::mp11 safeint_interface
                                                                ${WIL_TARGET} Eigen3::Eigen)
	target_compile_definitions(onnxruntime_providers_dml PRIVATE FILE_NAME=\"onnxruntime_providers_dml.dll\")
	add_dependencies(onnxruntime_providers_dml onnxruntime_providers_shared ${onnxruntime_EXTERNAL_DEPENDENCIES})
	set_property(TARGET onnxruntime_providers_dml APPEND_STRING PROPERTY LINK_FLAGS "-DEF:${ONNXRUNTIME_ROOT}/core/providers/dml/symbols.def")
  else()
    set(onnxruntime_providers_dml_srcs ${onnxruntime_providers_dml_ep_srcs})
	source_group(TREE ${ONNXRUNTIME_ROOT}/core FILES ${onnxruntime_providers_dml_srcs})
	
	onnxruntime_add_static_library(onnxruntime_providers_dml ${onnxruntime_providers_dml_srcs})
	onnxruntime_add_include_to_target(onnxruntime_providers_dml onnxruntime_common onnxruntime_framework ${GSL_TARGET}
																onnx onnx_proto ${PROTOBUF_LIB} flatbuffers::flatbuffers 
																Boost::mp11 safeint_interface ${WIL_TARGET} Eigen3::Eigen)
	add_dependencies(onnxruntime_providers_dml onnx ${onnxruntime_EXTERNAL_DEPENDENCIES})
  endif()
  
  if(TARGET Microsoft::DirectX-Headers)
    onnxruntime_add_include_to_target(onnxruntime_providers_dml Microsoft::DirectX-Headers)
  endif()
  
  target_include_directories(onnxruntime_providers_dml PRIVATE
    ${ONNXRUNTIME_ROOT}
  )

  target_compile_definitions(onnxruntime_providers_dml PRIVATE DML_TARGET_VERSION_USE_LATEST=1)
  if(WIN32)
    target_compile_options(onnxruntime_providers_dml PRIVATE "/wd4100" "/wd4238" "/wd4189" "/wd4702")
  endif()

  if (NOT onnxruntime_USE_CUSTOM_DIRECTML)
    foreach(file "DirectML.dll" "DirectML.pdb" "DirectML.Debug.dll" "DirectML.Debug.pdb")
      add_custom_command(TARGET onnxruntime_providers_dml
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
          "${DML_PACKAGE_DIR}/bin/${onnxruntime_target_platform}-win/${file}" $<TARGET_FILE_DIR:onnxruntime_providers_dml>)
    endforeach()
  endif()

  function(target_add_dml target)
    if (onnxruntime_USE_CUSTOM_DIRECTML)
      if (dml_EXTERNAL_PROJECT)
        # Internal build of DirectML: link against the "DirectML" target.
        target_link_libraries(${target} PRIVATE DirectML)
      else()
        if (dml_LIB_DIR)
          target_link_libraries(${target} PRIVATE ${dml_LIB_DIR}/DirectML.lib)
        else()
          target_link_libraries(${target} PRIVATE DirectML)
        endif()
      endif()
    else()
      add_dependencies(${target} RESTORE_PACKAGES)
      target_link_libraries(${target} PRIVATE "${DML_PACKAGE_DIR}/bin/${onnxruntime_target_platform}-win/DirectML.lib")
      target_compile_definitions(${target} PRIVATE DML_TARGET_VERSION_USE_LATEST)
    endif()
  endfunction()

  target_add_dml(onnxruntime_providers_dml)
  target_link_libraries(onnxruntime_providers_dml PRIVATE ${ONNXRUNTIME_PROVIDERS_SHARED} onnxruntime_common onnxruntime_framework)
  if (GDK_PLATFORM STREQUAL Scarlett)
    target_link_libraries(onnxruntime_providers_dml PRIVATE ${gdk_dx_libs})
  else()
    target_link_libraries(onnxruntime_providers_dml PRIVATE dxguid.lib d3d12.lib dxgi.lib)
  endif()

  target_link_libraries(onnxruntime_providers_dml PRIVATE delayimp.lib)

  if (onnxruntime_ENABLE_DELAY_LOADING_WIN_DLLS AND NOT GDK_PLATFORM)
    #NOTE: the flags are only applied to onnxruntime.dll and the PYD file in our python package. Our C/C++ unit tests do not use these flags.
    list(APPEND onnxruntime_DELAYLOAD_FLAGS "/DELAYLOAD:DirectML.dll" "/DELAYLOAD:d3d12.dll" "/DELAYLOAD:dxgi.dll" "/DELAYLOAD:dxcore.dll" "/DELAYLOAD:api-ms-win-core-com-l1-1-0.dll" "/DELAYLOAD:shlwapi.dll" "/DELAYLOAD:oleaut32.dll" "/DELAYLOAD:ext-ms-win-dxcore-l1-*.dll" "/ignore:4199")
  endif()

  target_compile_definitions(onnxruntime_providers_dml
    PRIVATE
    ONNX_NAMESPACE=onnx ONNX_ML LOTUS_LOG_THRESHOLD=2 LOTUS_ENABLE_STDERR_LOGGING PLATFORM_WINDOWS
  )
  target_compile_definitions(onnxruntime_providers_dml PRIVATE UNICODE _UNICODE NOMINMAX)
  if (MSVC)
    target_compile_definitions(onnxruntime_providers_dml PRIVATE _SILENCE_CXX17_ITERATOR_BASE_CLASS_DEPRECATION_WARNING)
    target_compile_options(onnxruntime_providers_dml PRIVATE "/W3")
  endif()

  install(FILES ${PROJECT_SOURCE_DIR}/../include/onnxruntime/core/providers/dml/dml_provider_factory.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/onnxruntime/
  )
  

  set_target_properties(onnxruntime_providers_dml PROPERTIES LINKER_LANGUAGE CXX)
  set_target_properties(onnxruntime_providers_dml PROPERTIES FOLDER "ONNXRuntime")

if (NOT onnxruntime_BUILD_SHARED_LIB)
	install(TARGETS onnxruntime_providers_dml EXPORT ${PROJECT_NAME}Targets
		  ARCHIVE   DESTINATION ${CMAKE_INSTALL_LIBDIR}
		  LIBRARY   DESTINATION ${CMAKE_INSTALL_LIBDIR}
		  RUNTIME   DESTINATION ${CMAKE_INSTALL_BINDIR}
		  FRAMEWORK DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()
