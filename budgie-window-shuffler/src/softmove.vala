using Math;

/*
* ShufflerIII
* Author: Jacob Vlijm
* Copyright © 2017-2022 Ubuntu Budgie Developers
* Website=https://ubuntubudgie.org
* This program is free software: you can redistribute it and/or modify it
* under the terms of the GNU General Public License as published by the Free
* Software Foundation, either version 3 of the License, or any later version.
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
* FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
* more details. You should have received a copy of the GNU General Public
* License along with this program.  If not, see
* <https://www.gnu.org/licenses/>.
*/


namespace CalculateTracks {

    [DBus (name = "org.UbuntuBudgie.ShufflerInfoDaemon")]

    interface ShufflerInfoClient : Object {
        public abstract GLib.HashTable<string, Variant> get_winsdata () throws Error;
        public abstract void move_window (int wid, int x, int y, int width, int height, bool nowarning = false) throws Error;
        public abstract int[] get_winspecs (int w_id) throws Error;
    }

    public static void main (string[] args) {
        // targeted x, y, w, h
        try {
            ShufflerInfoClient client = Bus.get_proxy_sync (
                BusType.SESSION, "org.UbuntuBudgie.ShufflerInfoDaemon",
                ("/org/ubuntubudgie/shufflerinfodaemon")
            );
            int wid = int.parse(args[1]);
            int trg_x = int.parse(args[2]);
            int trg_y = int.parse(args[3]);
            int trg_w = int.parse(args[4]);
            int trg_h = int.parse(args[5]);
            //  calctracks(client, wid, trg_x, trg_y, trg_w, trg_h);
            int[] originals = get_startposition(client, wid);
            int yshift = client.get_winspecs(wid)[0];
            // get from server
            int orig_x = originals[0];
            int orig_y = originals[1];
            // let's see which of the properties shows the biggest change
            int xtrack = trg_x - orig_x;
            int ytrack = trg_y - orig_y;
            double[] xarr = {};
            double[] yarr = {};
            // find largest track
            int[] tracks = {xtrack, ytrack};
            int largest = 0;
            int largest_abs = 0;
            int i = 0;
            int index = 0;
            foreach (int n in tracks) {
                int absval = n.abs();
                if (absval > largest_abs) {
                    largest = n;
                    largest_abs = absval;
                    index = i;
                }
                i += 1;
            }
            // steps array to calculate with, based on longest track
            double[] calc_array = {};
            double temp_largest = largest;
            double nextstep = 10000;
            while (fabs(nextstep) > 1) {
                nextstep = temp_largest / 4.0;
                calc_array += nextstep;
                temp_largest = temp_largest - nextstep;
            }
            // create acumulated values
            double[] accumulated = {};
            double temp_currtotal = 0;
            foreach (double d in calc_array) {
                temp_currtotal = temp_currtotal + d;
                accumulated += temp_currtotal;
            }
            // now fill in all arrays (accumulated)
            foreach (double ad in accumulated) {
                double relative = ad / largest;
                xarr += (double)orig_x + (round(relative * (double)xtrack));
                // now think of that: ((1 - relative) * yshift) (!)
                yarr += (double)orig_y + (round(relative * (double)ytrack)) - ((1 - relative) * yshift);
            }
            // now first resize, one step
            client.move_window(wid, orig_x, orig_y - yshift, trg_w, trg_h, true);
            Thread.usleep(3000);
            // then make the move
            int ind = 0;
            int xn = 0;
            int yn = 0;
            foreach (double d in xarr) {
                Thread.usleep(3000);
                xn = (int)xarr[ind];
                yn = (int)yarr[ind];
                client.move_window(wid, xn, yn , trg_w, trg_h, true);
                ind += 1;
            }
            // finish
            Thread.usleep(3000);
            client.move_window(wid, trg_x, trg_y, trg_w, trg_h, true);
        }
        catch (Error e) {
        }
    }

    private int[] get_startposition (
        ShufflerInfoClient client, int wid
    ) {
        try {
            GLib.HashTable<string, Variant> windata = client.get_winsdata ();
            foreach (string k in windata.get_keys()) {
                if (@"$wid" == k) {
                    Variant match = windata[k];
                    int x = (int)match.get_child_value(3);
                    int y = (int)match.get_child_value(4);
                    return {x, y};
                }
            }
        }
        catch (Error e) {
            return {0, 0};
        }
        return {0, 0};
    }
}