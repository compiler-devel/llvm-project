//===----------------------------------------------------------------------===//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// XFAIL: LIBCXX-FREEBSD-FIXME

// UNSUPPORTED: c++03, c++11, c++14, c++17
// UNSUPPORTED: no-localization
// UNSUPPORTED: libcpp-has-no-incomplete-format

// TODO FMT Investigate Windows issues.
// UNSUPPORTED: msvc, target={{.+}}-windows-gnu

// TODO FMT Fix this test using GCC, it currently crashes.
// UNSUPPORTED: gcc-12

// TODO FMT This test should not require std::to_chars(floating-point)
// This test requires std::to_chars(floating-point), which is in the dylib
// XFAIL: use_system_cxx_lib && target={{.+}}-apple-macosx{{10.9|10.10|10.11|10.12|10.13|10.14|10.15|11.0}}

// REQUIRES: locale.fr_FR.UTF-8
// REQUIRES: locale.ja_JP.UTF-8

// <chrono>

// template<class charT> struct formatter<chrono::weekday, charT>;

#include <chrono>
#include <format>

#include <cassert>
#include <concepts>
#include <locale>
#include <iostream>
#include <type_traits>

#include "formatter_tests.h"
#include "make_string.h"
#include "platform_support.h" // locale name macros
#include "test_macros.h"

template <class CharT>
static void test_no_chrono_specs() {
  using namespace std::literals::chrono_literals;

  // Valid day
  check(SV("Sun"), SV("{}"), std::chrono::weekday(0));

  // Invalid day
  check(SV("8 is not a valid weekday"), SV("{}"), std::chrono::weekday(8));
}

template <class CharT>
static void test_valid_values() {
  constexpr std::basic_string_view<CharT> fmt =
      SV("{:%%u='%u'%t%%Ou='%Ou'%t%%w='%w'%t%%Ow='%Ow'%t%%a='%a'%t%%A='%A'%n}");
  constexpr std::basic_string_view<CharT> lfmt =
      SV("{:L%%u='%u'%t%%Ou='%Ou'%t%%w='%w'%t%%Ow='%Ow'%t%%a='%a'%t%%A='%A'%n}");

  const std::locale loc(LOCALE_ja_JP_UTF_8);
  std::locale::global(std::locale(LOCALE_fr_FR_UTF_8));

  // Non localized output using C-locale
  check(SV("%u='7'\t%Ou='7'\t%w='0'\t%Ow='0'\t%a='Sun'\t%A='Sunday'\n"), fmt, std::chrono::weekday(0));
  check(SV("%u='1'\t%Ou='1'\t%w='1'\t%Ow='1'\t%a='Mon'\t%A='Monday'\n"), fmt, std::chrono::weekday(1));
  check(SV("%u='2'\t%Ou='2'\t%w='2'\t%Ow='2'\t%a='Tue'\t%A='Tuesday'\n"), fmt, std::chrono::weekday(2));
  check(SV("%u='3'\t%Ou='3'\t%w='3'\t%Ow='3'\t%a='Wed'\t%A='Wednesday'\n"), fmt, std::chrono::weekday(3));
  check(SV("%u='4'\t%Ou='4'\t%w='4'\t%Ow='4'\t%a='Thu'\t%A='Thursday'\n"), fmt, std::chrono::weekday(4));
  check(SV("%u='5'\t%Ou='5'\t%w='5'\t%Ow='5'\t%a='Fri'\t%A='Friday'\n"), fmt, std::chrono::weekday(5));
  check(SV("%u='6'\t%Ou='6'\t%w='6'\t%Ow='6'\t%a='Sat'\t%A='Saturday'\n"), fmt, std::chrono::weekday(6));
  check(SV("%u='7'\t%Ou='7'\t%w='0'\t%Ow='0'\t%a='Sun'\t%A='Sunday'\n"), fmt, std::chrono::weekday(7));

#if defined(__APPLE__)
  // Use the global locale (fr_FR)
  check(SV("%u='7'\t%Ou='7'\t%w='0'\t%Ow='0'\t%a='Dim'\t%A='Dimanche'\n"), lfmt, std::chrono::weekday(0));
  check(SV("%u='1'\t%Ou='1'\t%w='1'\t%Ow='1'\t%a='Lun'\t%A='Lundi'\n"), lfmt, std::chrono::weekday(1));
  check(SV("%u='2'\t%Ou='2'\t%w='2'\t%Ow='2'\t%a='Mar'\t%A='Mardi'\n"), lfmt, std::chrono::weekday(2));
  check(SV("%u='3'\t%Ou='3'\t%w='3'\t%Ow='3'\t%a='Mer'\t%A='Mercredi'\n"), lfmt, std::chrono::weekday(3));
  check(SV("%u='4'\t%Ou='4'\t%w='4'\t%Ow='4'\t%a='Jeu'\t%A='Jeudi'\n"), lfmt, std::chrono::weekday(4));
  check(SV("%u='5'\t%Ou='5'\t%w='5'\t%Ow='5'\t%a='Ven'\t%A='Vendredi'\n"), lfmt, std::chrono::weekday(5));
  check(SV("%u='6'\t%Ou='6'\t%w='6'\t%Ow='6'\t%a='Sam'\t%A='Samedi'\n"), lfmt, std::chrono::weekday(6));
  check(SV("%u='7'\t%Ou='7'\t%w='0'\t%Ow='0'\t%a='Dim'\t%A='Dimanche'\n"), lfmt, std::chrono::weekday(7));
#else
  // Use the global locale (fr_FR)
  check(SV("%u='7'\t%Ou='7'\t%w='0'\t%Ow='0'\t%a='dim.'\t%A='dimanche'\n"), lfmt, std::chrono::weekday(0));
  check(SV("%u='1'\t%Ou='1'\t%w='1'\t%Ow='1'\t%a='lun.'\t%A='lundi'\n"), lfmt, std::chrono::weekday(1));
  check(SV("%u='2'\t%Ou='2'\t%w='2'\t%Ow='2'\t%a='mar.'\t%A='mardi'\n"), lfmt, std::chrono::weekday(2));
  check(SV("%u='3'\t%Ou='3'\t%w='3'\t%Ow='3'\t%a='mer.'\t%A='mercredi'\n"), lfmt, std::chrono::weekday(3));
  check(SV("%u='4'\t%Ou='4'\t%w='4'\t%Ow='4'\t%a='jeu.'\t%A='jeudi'\n"), lfmt, std::chrono::weekday(4));
  check(SV("%u='5'\t%Ou='5'\t%w='5'\t%Ow='5'\t%a='ven.'\t%A='vendredi'\n"), lfmt, std::chrono::weekday(5));
  check(SV("%u='6'\t%Ou='6'\t%w='6'\t%Ow='6'\t%a='sam.'\t%A='samedi'\n"), lfmt, std::chrono::weekday(6));
  check(SV("%u='7'\t%Ou='7'\t%w='0'\t%Ow='0'\t%a='dim.'\t%A='dimanche'\n"), lfmt, std::chrono::weekday(7));
#endif

  // Use supplied locale (ja_JP).
  // This locale has a different alternate, but not on all platforms
#if defined(_WIN32) || defined(__APPLE__) || defined(_AIX)
  check(loc, SV("%u='7'\t%Ou='7'\t%w='0'\t%Ow='0'\t%a='日'\t%A='日曜日'\n"), lfmt, std::chrono::weekday(0));
  check(loc, SV("%u='1'\t%Ou='1'\t%w='1'\t%Ow='1'\t%a='月'\t%A='月曜日'\n"), lfmt, std::chrono::weekday(1));
  check(loc, SV("%u='2'\t%Ou='2'\t%w='2'\t%Ow='2'\t%a='火'\t%A='火曜日'\n"), lfmt, std::chrono::weekday(2));
  check(loc, SV("%u='3'\t%Ou='3'\t%w='3'\t%Ow='3'\t%a='水'\t%A='水曜日'\n"), lfmt, std::chrono::weekday(3));
  check(loc, SV("%u='4'\t%Ou='4'\t%w='4'\t%Ow='4'\t%a='木'\t%A='木曜日'\n"), lfmt, std::chrono::weekday(4));
  check(loc, SV("%u='5'\t%Ou='5'\t%w='5'\t%Ow='5'\t%a='金'\t%A='金曜日'\n"), lfmt, std::chrono::weekday(5));
  check(loc, SV("%u='6'\t%Ou='6'\t%w='6'\t%Ow='6'\t%a='土'\t%A='土曜日'\n"), lfmt, std::chrono::weekday(6));
  check(loc, SV("%u='7'\t%Ou='7'\t%w='0'\t%Ow='0'\t%a='日'\t%A='日曜日'\n"), lfmt, std::chrono::weekday(7));
#else
  check(loc, SV("%u='7'\t%Ou='七'\t%w='0'\t%Ow='〇'\t%a='日'\t%A='日曜日'\n"), lfmt, std::chrono::weekday(0));
  check(loc, SV("%u='1'\t%Ou='一'\t%w='1'\t%Ow='一'\t%a='月'\t%A='月曜日'\n"), lfmt, std::chrono::weekday(1));
  check(loc, SV("%u='2'\t%Ou='二'\t%w='2'\t%Ow='二'\t%a='火'\t%A='火曜日'\n"), lfmt, std::chrono::weekday(2));
  check(loc, SV("%u='3'\t%Ou='三'\t%w='3'\t%Ow='三'\t%a='水'\t%A='水曜日'\n"), lfmt, std::chrono::weekday(3));
  check(loc, SV("%u='4'\t%Ou='四'\t%w='4'\t%Ow='四'\t%a='木'\t%A='木曜日'\n"), lfmt, std::chrono::weekday(4));
  check(loc, SV("%u='5'\t%Ou='五'\t%w='5'\t%Ow='五'\t%a='金'\t%A='金曜日'\n"), lfmt, std::chrono::weekday(5));
  check(loc, SV("%u='6'\t%Ou='六'\t%w='6'\t%Ow='六'\t%a='土'\t%A='土曜日'\n"), lfmt, std::chrono::weekday(6));
  check(loc, SV("%u='7'\t%Ou='七'\t%w='0'\t%Ow='〇'\t%a='日'\t%A='日曜日'\n"), lfmt, std::chrono::weekday(7));
#endif

  std::locale::global(std::locale::classic());
}

template <class CharT>
static void test_invalid_values() {
  // Test that %a and %A throw an exception.
  check_exception("formatting a weekday name needs a valid weekday", SV("{:%a}"), std::chrono::weekday(8));
  check_exception("formatting a weekday name needs a valid weekday", SV("{:%a}"), std::chrono::weekday(255));
  check_exception("formatting a weekday name needs a valid weekday", SV("{:%A}"), std::chrono::weekday(8));
  check_exception("formatting a weekday name needs a valid weekday", SV("{:%A}"), std::chrono::weekday(255));

  constexpr std::basic_string_view<CharT> fmt  = SV("{:%%u='%u'%t%%Ou='%Ou'%t%%w='%w'%t%%Ow='%Ow'%n}");
  constexpr std::basic_string_view<CharT> lfmt = SV("{:L%%u='%u'%t%%Ou='%Ou'%t%%w='%w'%t%%Ow='%Ow'%n}");

  const std::locale loc(LOCALE_ja_JP_UTF_8);
  std::locale::global(std::locale(LOCALE_fr_FR_UTF_8));

#if defined(__APPLE__)
  // Non localized output using C-locale
  check(SV("%u='8'\t%Ou='8'\t%w='8'\t%Ow='8'\n"), fmt, std::chrono::weekday(8));
  check(SV("%u='255'\t%Ou='255'\t%w='255'\t%Ow='255'\n"), fmt, std::chrono::weekday(255));

  // Use the global locale (fr_FR)
  check(SV("%u='8'\t%Ou='8'\t%w='8'\t%Ow='8'\n"), lfmt, std::chrono::weekday(8));
  check(SV("%u='255'\t%Ou='255'\t%w='255'\t%Ow='255'\n"), lfmt, std::chrono::weekday(255));

  // Use supplied locale (ja_JP). This locale has a different alternate.
  check(loc, SV("%u='8'\t%Ou='8'\t%w='8'\t%Ow='8'\n"), lfmt, std::chrono::weekday(8));
  check(loc, SV("%u='255'\t%Ou='255'\t%w='255'\t%Ow='255'\n"), lfmt, std::chrono::weekday(255));
#elif defined(_AIX)
  // Non localized output using C-locale
  check(SV("%u='8'\t%Ou='8'\t%w='8'\t%Ow='8'\n"), fmt, std::chrono::weekday(8));
  check(SV("%u='5'\t%Ou='5'\t%w='5'\t%Ow='5'\n"), fmt, std::chrono::weekday(255));

  // Use the global locale (fr_FR)
  check(SV("%u='8'\t%Ou='8'\t%w='8'\t%Ow='8'\n"), lfmt, std::chrono::weekday(8));
  check(SV("%u='5'\t%Ou='5'\t%w='5'\t%Ow='5'\n"), lfmt, std::chrono::weekday(255));

  // Use supplied locale (ja_JP). This locale has a different alternate.
  check(loc, SV("%u='8'\t%Ou='8'\t%w='8'\t%Ow='8'\n"), lfmt, std::chrono::weekday(8));
  check(loc, SV("%u='5'\t%Ou='5'\t%w='5'\t%Ow='5'\n"), lfmt, std::chrono::weekday(255));
#else
  // Non localized output using C-locale
  check(SV("%u='1'\t%Ou='1'\t%w='8'\t%Ow='8'\n"), fmt, std::chrono::weekday(8));
  check(SV("%u='3'\t%Ou='3'\t%w='255'\t%Ow='255'\n"), fmt, std::chrono::weekday(255));

  // Use the global locale (fr_FR)
  check(SV("%u='1'\t%Ou='1'\t%w='8'\t%Ow='8'\n"), lfmt, std::chrono::weekday(8));
  check(SV("%u='3'\t%Ou='3'\t%w='255'\t%Ow='255'\n"), lfmt, std::chrono::weekday(255));

  // Use supplied locale (ja_JP). This locale has a different alternate.
  check(loc, SV("%u='1'\t%Ou='一'\t%w='8'\t%Ow='八'\n"), lfmt, std::chrono::weekday(8));
  check(loc, SV("%u='3'\t%Ou='三'\t%w='255'\t%Ow='255'\n"), lfmt, std::chrono::weekday(255));

#endif

  std::locale::global(std::locale::classic());
}

template <class CharT>
static void test() {
  test_no_chrono_specs<CharT>();
  test_valid_values<CharT>();
  test_invalid_values<CharT>();
  check_invalid_types<CharT>(
      {SV("a"), SV("A"), SV("t"), SV("u"), SV("w"), SV("Ou"), SV("Ow")}, std::chrono::weekday(0));

  check_exception("Expected '%' or '}' in the chrono format-string", SV("{:A"), std::chrono::weekday(0));
  check_exception("The chrono-specs contains a '{'", SV("{:%%{"), std::chrono::weekday(0));
  check_exception("End of input while parsing the modifier chrono conversion-spec", SV("{:%"), std::chrono::weekday(0));
  check_exception("End of input while parsing the modifier E", SV("{:%E"), std::chrono::weekday(0));
  check_exception("End of input while parsing the modifier O", SV("{:%O"), std::chrono::weekday(0));

  // Precision not allowed
  check_exception("Expected '%' or '}' in the chrono format-string", SV("{:.3}"), std::chrono::weekday(0));
}

int main(int, char**) {
  test<char>();

#ifndef TEST_HAS_NO_WIDE_CHARACTERS
  test<wchar_t>();
#endif

  return 0;
}
