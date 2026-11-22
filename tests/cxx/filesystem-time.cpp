#include <iostream>
#include <filesystem>
#include <fstream>
#include <thread>
#include <chrono>
#include <condition_variable>
#include <mutex>
#include <ctime>
namespace fs=std::filesystem; using namespace std::chrono;
int main(){
  fs::create_directories("/tmp/cpp3/sub"); { std::ofstream("/tmp/cpp3/a.txt") << "12345"; }
  std::cout<<"size "<<fs::file_size("/tmp/cpp3/a.txt")<<" dir "<<fs::is_directory("/tmp/cpp3/sub")<<"\n";
  auto lw=fs::last_write_time("/tmp/cpp3/a.txt"); auto age=duration_cast<seconds>(fs::file_time_type::clock::now()-lw).count();
  std::cout<<"age_s "<<age<<"\n";
  int n=0; for(auto&e:fs::directory_iterator("/tmp/cpp3")) n+=1; std::cout<<"entries "<<n<<"\n";
  auto t0=steady_clock::now(); std::this_thread::sleep_for(milliseconds(120)); 
  std::cout<<"slept_ms "<<duration_cast<milliseconds>(steady_clock::now()-t0).count()<<"\n";
  std::mutex m; std::condition_variable cv; std::unique_lock<std::mutex> l(m); t0=steady_clock::now();
  bool r=cv.wait_for(l,milliseconds(150),[]{return false;}); std::cout<<"cv_timeout "<<!r<<" ms "<<duration_cast<milliseconds>(steady_clock::now()-t0).count()<<"\n";
  auto sc=system_clock::to_time_t(system_clock::now()); std::cout<<"year "<<1900+std::localtime(&sc)->tm_year<<"\n";
  fs::remove_all("/tmp/cpp3");
}
