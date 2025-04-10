// Package ufmt provides utility functions for formatting strings, similarly
// to the Go package "fmt", of which only a subset is currently supported
// (hence the name µfmt - micro fmt).
package ufmt

import (
	"errors"
	"strconv"
	"strings"
)

// Println formats using the default formats for its operands and writes to standard output.
// Println writes the given arguments to standard output with spaces between arguments
// and a newline at the end.
func Println(args ...any) {
	var strs []string
	for _, arg := range args {
		switch v := arg.(type) {
		case string:
			strs = append(strs, v)
		case (interface{ String() string }):
			strs = append(strs, v.String())
		case error:
			strs = append(strs, v.Error())
		case float64:
			strs = append(strs, Sprintf("%f", v))
		case int, int8, int16, int32, int64, uint, uint8, uint16, uint32, uint64:
			strs = append(strs, Sprintf("%d", v))
		case bool:
			if v {
				strs = append(strs, "true")
			} else {
				strs = append(strs, "false")
			}
		case nil:
			strs = append(strs, "<nil>")
		default:
			strs = append(strs, "(unhandled)")
		}
	}

	// TODO: remove println after gno supports os.Stdout
	println(strings.Join(strs, " "))
}

// Sprintf offers similar functionality to Go's fmt.Sprintf, or the sprintf
// equivalent available in many languages, including C/C++.
// The number of args passed must exactly match the arguments consumed by the format.
// A limited number of formatting verbs and features are currently supported,
// hence the name ufmt (µfmt, micro-fmt).
//
// The currently formatted verbs are the following:
//
//		%s: places a string value directly.
//		    If the value implements the interface interface{ String() string },
//		    the String() method is called to retrieve the value. Same about Error()
//		    string.
//		%c: formats the character represented by Unicode code point
//		%d: formats an integer value using package "strconv".
//		    Currently supports only uint, uint64, int, int64.
//		%f: formats a float value, with a default precision of 6.
//		%e: formats a float with scientific notation; 1.23456e+78
//		%E: formats a float with scientific notation; 1.23456E+78
//		%F: The same as %f
//		%g: formats a float value with %e for large exponents, and %f with full precision for smaller numbers
//		%G: formats a float value with %G for large exponents, and %F with full precision for smaller numbers
//		%t: formats a boolean value to "true" or "false".
//		%x: formats an integer value as a hexadecimal string.
//		    Currently supports only uint8, []uint8, [32]uint8.
//		%c: formats a rune value as a string.
//		    Currently supports only rune, int.
//		%q: formats a string value as a quoted string.
//		%T: formats the type of the value.
//	     %v: formats the value with a default representation appropriate for the value's type
//		%%: outputs a literal %. Does not consume an argument.
func Sprintf(format string, args ...any) string {
	// we use runes to handle multi-byte characters
	sTor := []rune(format)
	end := len(sTor)
	argNum := 0
	argLen := len(args)
	buf := ""

	for i := 0; i < end; {
		isLast := i == end-1
		c := string(sTor[i])

		if isLast || c != "%" {
			// we don't check for invalid format like a one ending with "%"
			buf += string(c)
			i++
			continue
		}

		verb := string(sTor[i+1])
		if verb == "%" {
			buf += "%"
			i += 2
			continue
		}

		if argNum > argLen {
			panic("invalid number of arguments to ufmt.Sprintf")
		}
		arg := args[argNum]
		argNum++

		switch verb {
		case "v":
			switch v := arg.(type) {
			case nil:
				buf += "<nil>"
			case bool:
				if v {
					buf += "true"
				} else {
					buf += "false"
				}
			case int:
				buf += strconv.Itoa(v)
			case int8:
				buf += strconv.Itoa(int(v))
			case int16:
				buf += strconv.Itoa(int(v))
			case int32:
				buf += strconv.Itoa(int(v))
			case int64:
				buf += strconv.Itoa(int(v))
			case uint:
				buf += strconv.FormatUint(uint64(v), 10)
			case uint8:
				buf += strconv.FormatUint(uint64(v), 10)
			case uint16:
				buf += strconv.FormatUint(uint64(v), 10)
			case uint32:
				buf += strconv.FormatUint(uint64(v), 10)
			case uint64:
				buf += strconv.FormatUint(v, 10)
			case float64:
				buf += strconv.FormatFloat(v, 'g', -1, 64)
			case string:
				buf += v
			case []byte:
				buf += string(v)
			case []rune:
				buf += string(v)
			case interface{ String() string }:
				buf += v.String()
			case error:
				buf += v.Error()
			default:
				buf += fallback(verb, v)
			}
		case "s":
			switch v := arg.(type) {
			case interface{ String() string }:
				buf += v.String()
			case error:
				buf += v.Error()
			case string:
				buf += v
			default:
				buf += fallback(verb, v)
			}
		case "c":
			switch v := arg.(type) {
			// rune is int32. Exclude overflowing numeric types and dups (byte, int32):
			case rune:
				buf += string(v)
			case int:
				buf += string(v)
			case int8:
				buf += string(v)
			case int16:
				buf += string(v)
			case uint:
				buf += string(v)
			case uint8:
				buf += string(v)
			case uint16:
				buf += string(v)
			default:
				buf += fallback(verb, v)
			}
		case "d":
			switch v := arg.(type) {
			case int:
				buf += strconv.Itoa(v)
			case int8:
				buf += strconv.Itoa(int(v))
			case int16:
				buf += strconv.Itoa(int(v))
			case int32:
				buf += strconv.Itoa(int(v))
			case int64:
				buf += strconv.Itoa(int(v))
			case uint:
				buf += strconv.FormatUint(uint64(v), 10)
			case uint8:
				buf += strconv.FormatUint(uint64(v), 10)
			case uint16:
				buf += strconv.FormatUint(uint64(v), 10)
			case uint32:
				buf += strconv.FormatUint(uint64(v), 10)
			case uint64:
				buf += strconv.FormatUint(v, 10)
			default:
				buf += fallback(verb, v)
			}
		case "e", "E", "f", "F", "g", "G":
			switch v := arg.(type) {
			case float64:
				switch verb {
				case "e":
					buf += strconv.FormatFloat(v, byte('e'), -1, 64)
				case "E":
					buf += strconv.FormatFloat(v, byte('E'), -1, 64)
				case "f", "F":
					buf += strconv.FormatFloat(v, byte('f'), 6, 64)
				case "g":
					buf += strconv.FormatFloat(v, byte('g'), -1, 64)
				case "G":
					buf += strconv.FormatFloat(v, byte('G'), -1, 64)
				}
			default:
				buf += fallback(verb, v)
			}
		case "t":
			switch v := arg.(type) {
			case bool:
				if v {
					buf += "true"
				} else {
					buf += "false"
				}
			default:
				buf += fallback(verb, v)
			}
		case "x":
			switch v := arg.(type) {
			case uint8:
				buf += strconv.FormatUint(uint64(v), 16)
			default:
				buf += "(unhandled)"
			}
		case "q":
			switch v := arg.(type) {
			case string:
				buf += strconv.Quote(v)
			default:
				buf += "(unhandled)"
			}
		case "T":
			switch arg.(type) {
			case bool:
				buf += "bool"
			case int:
				buf += "int"
			case int8:
				buf += "int8"
			case int16:
				buf += "int16"
			case int32:
				buf += "int32"
			case int64:
				buf += "int64"
			case uint:
				buf += "uint"
			case uint8:
				buf += "uint8"
			case uint16:
				buf += "uint16"
			case uint32:
				buf += "uint32"
			case uint64:
				buf += "uint64"
			case string:
				buf += "string"
			case []byte:
				buf += "[]byte"
			case []rune:
				buf += "[]rune"
			default:
				buf += "unknown"
			}
		// % handled before, as it does not consume an argument
		default:
			buf += "(unhandled verb: %" + verb + ")"
		}

		i += 2
	}
	if argNum < argLen {
		panic("too many arguments to ufmt.Sprintf")
	}
	return buf
}

// This function is used to mimic Go's fmt.Sprintf
// specific behaviour of showing verb/type mismatches,
// where for example:
//
//	fmt.Sprintf("%d", "foo") gives "%!d(string=foo)"
//
// Here:
//
//	fallback("s", 8) -> "%!s(int=8)"
//	fallback("d", nil) -> "%!d(<nil>)", and so on.
func fallback(verb string, arg any) string {
	var s string
	switch v := arg.(type) {
	case string:
		s = "string=" + v
	case (interface{ String() string }):
		s = "string=" + v.String()
	case error:
		// note: also "string=" in Go fmt
		s = "string=" + v.Error()
	case float64:
		s = "float64=" + Sprintf("%f", v)
	case int, int8, int16, int32, int64, uint, uint8, uint16, uint32, uint64:
		// note: rune, byte would be dups, being aliases
		if typename, e := typeToString(v); e != nil {
			panic("should not happen")
		} else {
			s = typename + "=" + Sprintf("%d", v)
		}
	case bool:
		if v {
			s = "bool=true"
		} else {
			s = "bool=false"
		}
	case nil:
		s = "<nil>"
	default:
		s = "(unhandled)"
	}
	return "%!" + verb + "(" + s + ")"
}

// Get the name of the type of `v` as a string.
// The recognized type of v is currently limited to native non-composite types.
// An error is returned otherwise.
func typeToString(v any) (string, error) {
	switch v.(type) {
	case string:
		return "string", nil
	case int:
		return "int", nil
	case int8:
		return "int8", nil
	case int16:
		return "int16", nil
	case int32:
		return "int32", nil
	case int64:
		return "int64", nil
	case uint:
		return "uint", nil
	case uint8:
		return "uint8", nil
	case uint16:
		return "uint16", nil
	case uint32:
		return "uint32", nil
	case uint64:
		return "uint64", nil
	case float32:
		return "float32", nil
	case float64:
		return "float64", nil
	case bool:
		return "bool", nil
	default:
		return "", errors.New("(unsupported type)")
	}
}

// errMsg implements the error interface.
type errMsg struct {
	msg string
}

// Error defines the requirements of the error interface.
// It functions similarly to Go's errors.New()
func (e *errMsg) Error() string {
	return e.msg
}

// Errorf is a function that mirrors the functionality of fmt.Errorf.
//
// It takes a format string and arguments to create a formatted string,
// then sets this string as the 'msg' field of an errMsg struct and returns a pointer to this struct.
//
// This function operates in a similar manner to Go's fmt.Errorf,
// providing a way to create formatted error messages.
//
// The currently formatted verbs are the following:
//
//	%s: places a string value directly.
//	    If the value implements the interface interface{ String() string },
//	    the String() method is called to retrieve the value. Same for error.
//	%c: formats the character represented by Unicode code point
//	%d: formats an integer value using package "strconv".
//	    Currently supports only uint, uint64, int, int64.
//	%t: formats a boolean value to "true" or "false".
//	%%: outputs a literal %. Does not consume an argument.
func Errorf(format string, args ...any) error {
	return &errMsg{Sprintf(format, args...)}
}
