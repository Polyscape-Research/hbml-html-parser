// Copyright (C) 2021-2024 Chadwain Holness
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pub const token = @import("src/token.zig");
pub const Tokenizer = @import("src/Tokenizer.zig");
pub const Dom = @import("src/Dom.zig");
pub const tree_construction = @import("src/tree_construction.zig");
pub const Parser = @import("src/Parser.zig");
pub const util = @import("src/util.zig");

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}
