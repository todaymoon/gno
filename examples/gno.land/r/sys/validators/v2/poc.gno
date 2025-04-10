package validators

import (
	"std"

	"gno.land/p/demo/dao"
	"gno.land/p/sys/validators"
	"gno.land/r/gov/dao/bridge"
)

const errNoChangesProposed = "no set changes proposed"

// NewPropExecutor creates a new executor that wraps a changes closure
// proposal. This wrapper is required to ensure the GovDAO Realm actually
// executed the callback.
//
// Concept adapted from:
// https://github.com/gnolang/gno/pull/1945
func NewPropExecutor(changesFn func() []validators.Validator) dao.Executor {
	if changesFn == nil {
		panic(errNoChangesProposed)
	}

	callback := func() error {
		for _, change := range changesFn() {
			if change.VotingPower == 0 {
				// This change request is to remove the validator
				removeValidator(change.Address)

				continue
			}

			// This change request is to add the validator
			addValidator(change)
		}

		return nil
	}

	return bridge.GovDAO().NewGovDAOExecutor(callback)
}

// IsValidator returns a flag indicating if the given bech32 address
// is part of the validator set
func IsValidator(addr std.Address) bool {
	return vp.IsValidator(addr)
}

// GetValidator returns the typed validator
func GetValidator(addr std.Address) validators.Validator {
	if validator, err := vp.GetValidator(addr); err == nil {
		return validator
	}

	panic("validator not found")
}

// GetValidators returns the typed validator set
func GetValidators() []validators.Validator {
	return vp.GetValidators()
}
