{- |
 Module : Notewell.Events
 Description : The program's event type and its constructors. 
 Copyright : Rose <rose@empty.town>
 License : BSD3
 Maintainer : rose@empty.town 
-}
module Notewell.Events where

import GI.Gtk (TextBuffer)

data Event = Closed                            -- ^ The window was closed.
           | OpenFileSelected (Maybe FilePath) -- ^ An open target was selected in the FileChooser.
           | NewClicked                        -- ^ The new document button was clicked.
           | OpenClicked                       -- ^ The open button was clicked.
           | SaveClicked                       -- ^ The save button was clicked.
           | SaveFileSelected (Maybe FilePath) -- ^ A save target was selected in the FileChooser.
           | Render                            -- ^ A change was made to the buffer.
