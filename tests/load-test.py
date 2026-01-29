#!/usr/bin/env python3
"""
Load Testing Script for Auto-Scaling Web Application
Generates concurrent HTTP requests to trigger CPU-based auto-scaling

Usage:
    python load-test.py <ALB_DNS_NAME> [duration_seconds] [concurrent_workers]
    
Example:
    python load-test.py devops-portfolio-alb-123456.us-east-1.elb.amazonaws.com 300 50
"""

import sys
import time
import threading
import urllib.request
import urllib.error
from datetime import datetime
from collections import defaultdict

class LoadTester:
    def __init__(self, target_url, duration=300, workers=50):
        self.target_url = target_url if target_url.startswith('http') else f'http://{target_url}'
        self.duration = duration
        self.workers = workers
        self.running = True
        self.stats = defaultdict(int)
        self.instance_hits = defaultdict(int)
        self.lock = threading.Lock()
        
    def make_request(self):
        """Make a single HTTP request"""
        try:
            req = urllib.request.Request(self.target_url, headers={'User-Agent': 'LoadTester/1.0'})
            with urllib.request.urlopen(req, timeout=10) as response:
                content = response.read().decode('utf-8')
                # Try to extract instance ID from response
                if 'i-' in content:
                    start = content.find('i-')
                    end = content.find('<', start)
                    if end > start:
                        instance_id = content[start:end].strip()
                        with self.lock:
                            self.instance_hits[instance_id] += 1
                return response.status
        except urllib.error.HTTPError as e:
            return e.code
        except Exception as e:
            return -1
            
    def worker(self):
        """Worker thread that continuously makes requests"""
        while self.running:
            status = self.make_request()
            with self.lock:
                if status == 200:
                    self.stats['success'] += 1
                elif status == -1:
                    self.stats['error'] += 1
                else:
                    self.stats[f'http_{status}'] += 1
            # Small delay between requests per worker
            time.sleep(0.1)
            
    def print_stats(self):
        """Print current statistics"""
        with self.lock:
            total = sum(self.stats.values())
            success = self.stats['success']
            errors = self.stats['error']
            
        print(f"\n{'='*60}")
        print(f"📊 Load Test Statistics @ {datetime.now().strftime('%H:%M:%S')}")
        print(f"{'='*60}")
        print(f"   Target: {self.target_url}")
        print(f"   Workers: {self.workers}")
        print(f"   Total Requests: {total:,}")
        print(f"   ✅ Successful: {success:,} ({success/max(total,1)*100:.1f}%)")
        print(f"   ❌ Errors: {errors:,}")
        
        if self.instance_hits:
            print(f"\n🔄 Load Balancing Distribution:")
            for instance, hits in sorted(self.instance_hits.items()):
                pct = hits / max(total, 1) * 100
                bar = '█' * int(pct / 2)
                print(f"   {instance}: {hits:,} ({pct:.1f}%) {bar}")
        print(f"{'='*60}\n")
        
    def run(self):
        """Run the load test"""
        print(f"""
╔══════════════════════════════════════════════════════════════╗
║  🚀 AUTO-SCALING LOAD TESTER                                 ║
╠══════════════════════════════════════════════════════════════╣
║  Target: {self.target_url[:50]:50} ║
║  Duration: {self.duration} seconds                                       ║
║  Concurrent Workers: {self.workers}                                       ║
╚══════════════════════════════════════════════════════════════╝
        """)
        
        print("Starting load test... Press Ctrl+C to stop early.\n")
        
        # Start worker threads
        threads = []
        for i in range(self.workers):
            t = threading.Thread(target=self.worker, daemon=True)
            t.start()
            threads.append(t)
            
        start_time = time.time()
        try:
            while time.time() - start_time < self.duration:
                time.sleep(10)  # Print stats every 10 seconds
                elapsed = int(time.time() - start_time)
                remaining = self.duration - elapsed
                print(f"⏱️  Elapsed: {elapsed}s | Remaining: {remaining}s")
                self.print_stats()
        except KeyboardInterrupt:
            print("\n\n⚠️  Load test interrupted by user!")
            
        self.running = False
        time.sleep(1)  # Let workers finish
        
        print("\n" + "="*60)
        print("🏁 FINAL RESULTS")
        self.print_stats()
        
        print("""
💡 TIPS FOR TRIGGERING AUTO-SCALING:
   1. Run this script for at least 5-10 minutes
   2. Use 50-100 concurrent workers
   3. Monitor CloudWatch CPU metrics
   4. Check ASG activity in AWS Console
   5. Watch instance count increase from 2 to 4-6
   
📊 To verify scaling:
   aws autoscaling describe-auto-scaling-groups \\
       --auto-scaling-group-names devops-portfolio-asg \\
       --query 'AutoScalingGroups[0].[DesiredCapacity,MinSize,MaxSize]'
        """)

def main():
    if len(sys.argv) < 2:
        print("Usage: python load-test.py <ALB_DNS_NAME> [duration_seconds] [concurrent_workers]")
        print("Example: python load-test.py my-alb-123.us-east-1.elb.amazonaws.com 300 50")
        sys.exit(1)
        
    target = sys.argv[1]
    duration = int(sys.argv[2]) if len(sys.argv) > 2 else 300
    workers = int(sys.argv[3]) if len(sys.argv) > 3 else 50
    
    tester = LoadTester(target, duration, workers)
    tester.run()

if __name__ == '__main__':
    main()
