require 'require_all'

module OsCtl
  module Template
    module Operations
      module Builder ; end
      module Config; end
      module Nix ; end
      module Template ; end
      module Test ; end
    end
  end
end

require_rel 'template/*.rb'
require_rel 'template/operations'