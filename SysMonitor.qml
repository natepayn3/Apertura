Process {
        id: metricsFetcher
        // One-liner with cross-vendor fallback handling logic for Nvidia, AMD, and Intel
        command: ["sh", "-c", "
            raw_temp=$(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1); 
            temp=$((raw_temp / 1000)); 
            while read -r m v _; do 
                case \"$m\" in MemTotal:) t=$v ;; MemAvailable:) a=$v ;; esac; 
            done < /proc/meminfo; 
            read -r _ u n s i iw irq sof _ < /proc/stat; 
            total=$((u + n + s + i + iw + irq + sof)); 
            idle=$((i + iw)); 
            df_out=$(df -h / | tail -n 1 | awk '{ u_val=$3; t_val=$2; sub(/[GGMK]/,\"\",u_val); sub(/[GGMK]/,\"\",t_val); print u_val\" \"t_val\" \"$5}'); 
            
            g_busy=0; g_temp=0;
            if command -v nvidia-smi >/dev/null 2>&1; then 
                nv_out=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null);
                g_busy=$(echo \"$nv_out\" | awk -F', ' '{print $1}');
                g_temp=$(echo \"$nv_out\" | awk -F', ' '{print $2}');
            else 
                for card in /sys/class/drm/card*/device; do
                    if [ -f \"$card/gpu_busy_percent\" ]; then
                        cur_b=$(cat \"$card/gpu_busy_percent\" 2>/dev/null);
                        [ \"$cur_b\" -gt \"$g_busy\" ] && g_busy=$cur_b;
                        hw_t=$(cat $card/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1);
                        [ ! -z \"$hw_t\" ] && g_temp=$((hw_t / 1000));
                    fi;
                done;
            fi;
            [ -z \"$g_busy\" ] && g_busy=0; [ -z \"$g_temp\" ] && g_temp=0;
            echo \"$total $idle $temp $a $t $df_out $g_busy $g_temp\"
        "]
        running: false

        stdout: StdioCollector {
            property int prevTotal: 0
            property int prevIdle: 0

            onTextChanged: {
                let cleaned = text.trim();
                if (!cleaned) return;
                let parts = cleaned.split(/\s+/); // Regular expression split keeps indices rigid even with uneven outputs
                if (parts.length < 10) return; 

                let curTotal = parseInt(parts[0]);
                let curIdle = parseInt(parts[1]);

                if (prevTotal !== 0) {
                    let diffTotal = curTotal - prevTotal;
                    let diffIdle = curIdle - prevIdle;
                    if (diffTotal > 0) {
                        monitorRoot.cpuPercent = Math.round(((diffTotal - diffIdle) / diffTotal) * 100);
                    }
                }
                prevTotal = curTotal;
                prevIdle = curIdle;

                monitorRoot.cpuTemp = parseInt(parts[2]);
                let availMem = parseFloat(parts[3]);
                let totalMem = parseFloat(parts[4]);

                monitorRoot.ramTotal = totalMem / 1024 / 1024;
                monitorRoot.ramUsed = (totalMem - availMem) / 1024 / 1024;
                monitorRoot.ramPercent = Math.round(((totalMem - availMem) / totalMem) * 100);
                
                monitorRoot.diskUsed = parts[5];
                monitorRoot.diskTotal = parts[6];
                monitorRoot.diskPercent = parseInt(parts[7].replace("%", ""));

                monitorRoot.gpuPercent = Math.min(Math.max(parseInt(parts[8]), 0), 100);
                monitorRoot.gpuTemp = Math.max(parseInt(parts[9]), 0);
            }
        }
    }
