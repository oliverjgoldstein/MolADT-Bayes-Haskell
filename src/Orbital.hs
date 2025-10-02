{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Declarative descriptions of atomic orbitals used to decorate atoms with
-- electron configuration information.  The structures are intentionally
-- simple data containers so that other modules can reuse them without
-- pulling in quantum-chemistry machinery.
module Orbital where

import Control.DeepSeq (NFData)
import Data.Maybe
import Chem.Molecule.Coordinate (Coordinate(..), mkAngstrom)
import Chem.Dietz ()
import GHC.Generics (Generic)
import Data.Binary (Binary)

-- Basic orbital types
data So = So
  deriving (Show, Eq, Read, Generic, NFData)

data P = Px | Py | Pz
  deriving (Show, Eq, Read, Generic, NFData)

data D = Dxy | Dyz | Dxz | Dx2y2 | Dz2
  deriving (Show, Eq, Read, Generic, NFData)

data F = Fxxx | Fxxy | Fxxz | Fxyy | Fxyz | Fxzz | Fzzz
  deriving (Show, Eq, Read, Generic, NFData)

-- A type to wrap one of the pure orbital types,
-- useful when describing the components of a hybrid orbital.
data PureOrbital = PureSo So
                 | PureP  P
                 | PureD  D
                 | PureF  F
                 deriving (Show, Eq, Read, Generic, NFData)

-- The Orbital type now includes an extra field for hybrid components.
-- For a pure orbital, `hybridComponents` is Nothing.
data Orbital subshellType = Orbital
  { orbitalType      :: subshellType
  , electronCount    :: Int
  , orientation      :: Maybe Coordinate
  , hybridComponents :: Maybe [(Double, PureOrbital)]
  } deriving (Show, Eq, Read, Generic, NFData)

-- | Convenience constructor for orientation vectors expressed directly in
-- Angstrom coordinates.
angCoord :: Double -> Double -> Double -> Coordinate
angCoord x y z = Coordinate (mkAngstrom x) (mkAngstrom y) (mkAngstrom z)

-- A SubShell is a list of Orbitals all having the same subshell type.
newtype SubShell subshellType = SubShell
  { orbitals :: [Orbital subshellType]
  } deriving (Show, Eq, Read, Generic, NFData)

-- A Shell has a principal quantum number and may contain s, p, d, and f subshells.
data Shell = Shell
  { principalQuantumNumber :: Int
  , sSubShell              :: Maybe (SubShell So)
  , pSubShell              :: Maybe (SubShell P)
  , dSubShell              :: Maybe (SubShell D)
  , fSubShell              :: Maybe (SubShell F)
  } deriving (Show, Eq, Read, Generic, NFData)

-- A Shells type is just a list of Shell.
type Shells = [Shell]

instance Binary So
instance Binary P
instance Binary D
instance Binary F
instance Binary PureOrbital
instance Binary subshellType => Binary (Orbital subshellType)
instance Binary subshellType => Binary (SubShell subshellType)
instance Binary Shell


-- | Hydrogen atom: 1s^1
hydrogen :: Shells
hydrogen =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 1
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]

-- | Carbon atom: 1s^2, 2s^2, 2p^2 (one electron in each of two p orbitals)
carbon :: Shells
carbon =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 2
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]

-- | Nitrogen atom: 1s^2, 2s^2, 2p^3
nitrogen :: Shells
nitrogen =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 2
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]

-- | Oxygen atom: 1s^2, 2s^2, 2p^4
oxygen :: Shells
oxygen =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 2
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]

-- | Boron atom: 1s^2, 2s^2, 2p^1
boron :: Shells
boron =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 2
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]

-- | Iron atom: 1s^2, 2s^2, 2p^6, 3s^2, 3p^6, 3d^6, 4s^2
iron :: Shells
iron =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 2
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 3
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = Dxy
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord (1/sqrt 2) (1/sqrt 2) 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dyz
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 (1/sqrt 2) (1/sqrt 2))
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dxz
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord (1/sqrt 2) 0 (1/sqrt 2))
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dx2y2
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord (1/sqrt 2) (-1/sqrt 2) 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dz2
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 4
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]

-- | Sodium atom: 1s^2, 2s^2, 2p^6, 3s^1
sodium :: Shells
sodium =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 2
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 3
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 1
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]

-- | Chlorine atom: 1s^2, 2s^2, 2p^5, 3s^2, 3p^5
chlorine :: Shells
chlorine =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 2
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 3
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]

-- | Fluorine atom: 1s^2, 2s^2, 2p^5
fluorine :: Shells
fluorine =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 2
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]

-- | Sulfur atom: 1s^2, 2s^2, 2p^6, 3s^2, 3p^4
sulfur :: Shells
sulfur =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 2
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 3
      , sSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell 
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]

-- | Bromine atom: 1s^2, 2s^2, 2p^6, 3s^2, 3p^6, 3d^10, 4s^2, 4p^5
bromine :: Shells
bromine =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 2
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 3
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Dxy
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord (1/sqrt 2) (1/sqrt 2) 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dyz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 (1/sqrt 2) (1/sqrt 2))
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dxz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord (1/sqrt 2) 0 (1/sqrt 2))
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dx2y2
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord (1/sqrt 2) (-1/sqrt 2) 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dz2
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 4
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 0
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]

-- | Phosphorus atom: 1s^2, 2s^2, 2p^6, 3s^2, 3p^3
phosphorus :: Shells
phosphorus =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 2
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 3
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]

-- | Iodine atom: 1s^2, 2s^2, 2p^6, 3s^2, 3p^6, 3d^10, 4s^2, 4p^6, 4d^10, 5s^2, 5p^5
iodine :: Shells
iodine =
  [ Shell
      { principalQuantumNumber = 1
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Nothing
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 2
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 3
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Dxy
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord (1/sqrt 2) (1/sqrt 2) 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dyz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 (1/sqrt 2) (1/sqrt 2))
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dxz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord (1/sqrt 2) 0 (1/sqrt 2))
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dx2y2
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord (1/sqrt 2) (-1/sqrt 2) 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dz2
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 4
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Dxy
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord (1/sqrt 2) (1/sqrt 2) 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dyz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 (1/sqrt 2) (1/sqrt 2))
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dxz
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord (1/sqrt 2) 0 (1/sqrt 2))
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dx2y2
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord (1/sqrt 2) (-1/sqrt 2) 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Dz2
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 0 0 1)
                                    , hybridComponents = Nothing
                                    }
                          ])
      , fSubShell = Nothing
      }
  , Shell
      { principalQuantumNumber = 5
      , sSubShell = Just (SubShell
                          [ Orbital { orbitalType      = So
                                    , electronCount    = 2
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , pSubShell = Just (SubShell
                          [ Orbital { orbitalType      = Px
                                    , electronCount    = 2
                                    , orientation      = Just (angCoord 1 0 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Py
                                    , electronCount    = 1
                                    , orientation      = Just (angCoord 0 1 0)
                                    , hybridComponents = Nothing
                                    }
                          , Orbital { orbitalType      = Pz
                                    , electronCount    = 0
                                    , orientation      = Nothing
                                    , hybridComponents = Nothing
                                    }
                          ])
      , dSubShell = Nothing
      , fSubShell = Nothing
      }
  ]