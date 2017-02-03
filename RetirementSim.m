function RetirementSim
clear all;close all;fclose all;
format long;format compact;
maxAgeMark = 90;
HealthInsuranceCostEscalation_Pct = 5;
ManagementExpenses_Pct = 1;
%ScenarioName = 'Stay in Maryland Bunker';
ScenarioName = 'Bicoastal Life, Ruth passes at 100, Then Move to Washington';
% ScenarioName = 'Stay in Maryland Bunker, Ruth Passes at 100';
StartYearSandP = [1927:1983];
%StartYearSandP = [1929];

Net_PreTax(1) = 1243143;
Net_PostTax(1) = 951762; 
InitialValue_APL_HealthInsurance_Pre65 = 979;
InitialValue_APL_HealthInsurance_Post65 = 423;
SocialSecurityIncome_Mark = 1895;
SocialSecurityIncome_Carol = 1109;
CarolPensionIncome = 1445;
Year(1) = 2016;
Month(1) = 3;
AggregateTaxRateFed_Pct = 15;
    
    
% LongTermCareInsuranceCostTable = [...
% 2016 107
% 2017 116
% 2018 125
% EVENTS.CASH_ADDITION.Table = [...
% 2017	6  133000
% 2026	2  400000
% 3000    1   0
% ];
% 

[SandP_InflationCorrectedReturnTable] = loadSandP;

h1 = figure;
ncases = length(StartYearSandP);
colormap('jet');
cmap = colormap;
a1 = size(cmap,1);

p = 1;
while 1;
    p = p+1;
    Year(p) = Year(p-1);
    Month(p) = Month(p-1) + 1;
    if Month(p) == 13;
        Month(p) = 1;
        Year(p) = Year(p) + 1;
    end
    Age_Mark0 = Year(p) - 1957 + (Month(p) - 6)/12;
    if Age_Mark0 > maxAgeMark;
        p = p-1;
        break
    end;
end
pmax = p;
Month = Month(1:pmax);
Year = Year(1:pmax);
[EVENTS] = defineScenario(ScenarioName,Month,Year)
ElapsedTime_Yrs = Year - Year(1) + (Month - Month(1))/12;
Age_Mark = Year - 1957 + (Month - 6)/12;
Age_Carol = Year - 1957 + (Month - 5)/12;
Social_Security_Mark = SocialSecurityIncome_Mark*(Age_Mark >= 62);
Social_Security_Carol = SocialSecurityIncome_Carol*(Age_Carol >= 62);
SocialSecurityBeforeTax = Social_Security_Mark + Social_Security_Carol;
Health_Insurance_Mark = ...
    InitialValue_APL_HealthInsurance_Pre65/2*...
            (1 + HealthInsuranceCostEscalation_Pct/100).^floor(ElapsedTime_Yrs).*(Age_Mark <65) ...
  + InitialValue_APL_HealthInsurance_Post65/2*...
            (1 + HealthInsuranceCostEscalation_Pct/100).^floor(ElapsedTime_Yrs).*(Age_Mark >=65);
Health_Insurance_Carol = ...
    InitialValue_APL_HealthInsurance_Pre65/2*...
            (1 + HealthInsuranceCostEscalation_Pct/100).^floor(ElapsedTime_Yrs).*(Age_Carol <65) ...
  + InitialValue_APL_HealthInsurance_Post65/2*...
            (1 + HealthInsuranceCostEscalation_Pct/100).^floor(ElapsedTime_Yrs).*(Age_Carol >=65);
Health_Insurance = Health_Insurance_Mark + Health_Insurance_Carol;

TotalExpenses = Health_Insurance + EVENTS.ExpensesOtherThanHealthcare + EVENTS.CASH_EXPENSES.value;
AggregateTaxRateNormal_Pct = EVENTS.STATE_TAX.AggregateTaxRateStateNormal_Pct + AggregateTaxRateFed_Pct;
AggregateTaxRateRet_Pct = EVENTS.STATE_TAX.AggregateTaxRateStateRet_Pct + AggregateTaxRateFed_Pct;      
TotalAfterTaxIncome = SocialSecurityBeforeTax.*(1-0.85*AggregateTaxRateRet_Pct/100) + ...
                CarolPensionIncome*(1- AggregateTaxRateRet_Pct/100);  
AfterTAxWithdrawal = (TotalExpenses - TotalAfterTaxIncome);

for q = 1:ncases;
    p = 1;
 
    Net_Total_AFterTax(p,q) = Net_PreTax(p)*(1- AggregateTaxRateRet_Pct(p)/100) + Net_PostTax(p);

    for p = 2:pmax
        IndexYear(p) = StartYearSandP(q) + floor(ElapsedTime_Yrs(p));
        RateOfReturn_B4_tax_pct_yearly(p) = interp1(SandP_InflationCorrectedReturnTable(:,1),SandP_InflationCorrectedReturnTable(:,2),IndexYear(p));
        RateOfReturn_B4_tax(p) = (1 + RateOfReturn_B4_tax_pct_yearly(p)/100)^(1/12) - 1;
        if RateOfReturn_B4_tax(p) > 0;
            RateOfReturn_Post_tax(p) = RateOfReturn_B4_tax(p)*(1- AggregateTaxRateNormal_Pct(p)/100);
        else
            RateOfReturn_Post_tax(p) = RateOfReturn_B4_tax(p);
        end
        Net_PreTax(p) = Net_PreTax(p-1)*(1 + RateOfReturn_B4_tax(p))*(1-ManagementExpenses_Pct/1200);
        Net_PostTax(p) = Net_PostTax(p-1)*(1 + RateOfReturn_Post_tax(p))*(1-ManagementExpenses_Pct/1200) + ...
            EVENTS.CASH_ADDITION.value(p);
        
        % Withdraw Expenses
        if Net_PreTax(p) > AfterTAxWithdrawal(p)/(1- AggregateTaxRateRet_Pct(p)/100);
            % take from Pre tax
            Net_PreTax(p) = max(Net_PreTax(p) - AfterTAxWithdrawal(p)/(1- AggregateTaxRateRet_Pct(p)/100),0);
        elseif Net_PostTax(p) > AfterTAxWithdrawal(p);
            % take from Post tax
            Net_PostTax(p) = max(Net_PostTax(p) - AfterTAxWithdrawal(p),0);
        else
            Net_PreTax(p) = 0;
            Net_PostTax(p) = 0;
        end
        Net_Total_AFterTax(p,q) = Net_PreTax(p)*(1- AggregateTaxRateRet_Pct(p)/100) + Net_PostTax(p);
    end
    pmax = p;
    if ncases == 1;
        ndx = 1;
    else
        ndx = 1 + (q - 1)*(a1 - 1)/(ncases - 1);
    end
    for mm=1:3;color_here(mm) = interp1((1:a1)',cmap(:,mm),ndx);end
    figure(h1);
    subplot(4,1,1);
    if ncases > 1;
        semilogy(Age_Mark(1:pmax),Net_Total_AFterTax(1:pmax,q)/1.e6,'color',color_here);grid on; hold on;
    else
        plot(Age_Mark(1:pmax),Net_Total_AFterTax(1:pmax,q)/1.e6,'color',color_here);grid on; hold on;
    end    
    text(Age_Mark(pmax),Net_Total_AFterTax(pmax,q)/1.e6,sprintf('%4i',StartYearSandP(q)));
end
if ncases == 1
    figure(h1);
    subplot(4,1,1);plot(Age_Mark(1:pmax),Net_PreTax(1:pmax)/1.e6,'r');grid on; hold on;
    subplot(4,1,1);plot(Age_Mark(1:pmax),Net_PostTax(1:pmax)/1.e6,'m');grid on; hold on;
    legend('Total','PreTax','PostTax')
end
xlabel('Age Mark');
ylabel('After Tax Valuation (Millions $)');
title({...
       sprintf('Event Scenario =  %s',ScenarioName),...
       sprintf('Health Insurance Cost Escalation = %3.2f %s',HealthInsuranceCostEscalation_Pct,'%'),...
       sprintf('Expenses Other Than Health Care = %s%2.0f %','$',EVENTS.ExpensesOtherThanHealthcare),...
       sprintf('S&P Index STart Years = %4i:%4i %',StartYearSandP(1),StartYearSandP(ncases)),...
       sprintf('Management Fees = %3.3f %s',ManagementExpenses_Pct,'%'),...
       });
figure(h1);subplot(4,1,2);
semilogy(Age_Mark(2:pmax),TotalExpenses(2:pmax),'bo',Age_Mark(2:pmax),Health_Insurance(2:pmax),'ro');grid on; hold on;
semilogy(Age_Mark(2:pmax),TotalAfterTaxIncome(2:pmax),'mo',Age_Mark(2:pmax),AfterTAxWithdrawal(2:pmax),'g*',...
    Age_Mark(2:pmax),EVENTS.CASH_ADDITION.value(2:pmax),'ko',...
    Age_Mark(2:pmax),EVENTS.CASH_EXPENSES.value(2:pmax),'c*');grid on; hold on;
legend('total expenses','health ins','after tax income','total after tax withdrawal','Cash Addition','Cash Expenses');
figure(h1);subplot(4,1,3);
plot(Age_Mark(2:pmax),AggregateTaxRateNormal_Pct(2:pmax),'bo-',Age_Mark(2:pmax),AggregateTaxRateRet_Pct(2:pmax),'ro-');grid on; hold on;
legend('Normal Aggregate Tax Rate','Retirement Aggregate Tax Rate');
if ncases == 1;
    plot(Age_Mark(2:pmax),RateOfReturn_B4_tax_pct_yearly(2:pmax),'mo-')
    legend('Normal Aggregate Tax Rate','Retirement Aggregate Tax Rate','Rate of return');
end
figure(h1);subplot(4,1,4);
numberCasesDrawnDown(1:pmax) = sum(Net_Total_AFterTax < Net_Total_AFterTax(1,1),2);
plot(Age_Mark(1:pmax),numberCasesDrawnDown(1:pmax),'bo-');grid on; hold on;
numberCasesLessThan2M(1:pmax) = sum(Net_Total_AFterTax < 2e6,2);
plot(Age_Mark(1:pmax),numberCasesLessThan2M(1:pmax),'co-');grid on; hold on;
numberCasesLessThan1P5M(1:pmax) = sum(Net_Total_AFterTax < 1.5e6,2);
plot(Age_Mark(1:pmax),numberCasesLessThan1P5M(1:pmax),'go-');grid on; hold on;
numberCasesLessThan1M(1:pmax) = sum(Net_Total_AFterTax < 1e6,2);
plot(Age_Mark(1:pmax),numberCasesLessThan1M(1:pmax),'mo-');grid on; hold on;
numberCasesBusted(1:pmax) = sum(Net_Total_AFterTax ==0 ,2);
plot(Age_Mark(1:pmax),numberCasesBusted(1:pmax),'ro-');grid on; hold on;
xlabel('Age Mark');ylabel('Number of cases');
legend('Less than begin','Less than 2M','Less than 1.5M','Less than 1M','Busted')
end
%----------------------------------------------------------------------
function [EVENTS] = defineScenario(ScenarioName,Month,Year)
% EVENTS.STATE_TAX.AggregateTaxRateStateNormal_Pct =   [9,0,0];
% EVENTS.STATE_TAX.AggregateTaxRateStateRet_Pct =      [9,0,0];
% EVENTS.STATE_TAX.StartDates = [...
%     2016 1
%     2017 6
%     3000 1];
if strcmp(ScenarioName,'Stay in Maryland Bunker');
    EVENTS.STATE_TAX.Table = [...
        2016 1 9 9
        3000 1 9 9];  % Third column is normal aggregate rate, fouth is retirement aggregate rate

    EVENTS.CASH_ADDITION.Table = [...
        2017	6  0
        2026	2  0
        3000    1  0
        ];

    EVENTS.CASH_EXPENSES.Table = [...
    2016    11  0
    2017     4  0
    2017     11 0
    2018     4  0
    2018     11 0
    2019     4  0
    2019     11 0
    2020     4  0
    2020     11 0
    3000     1  0
    ];

    EVENTS.ExpensesOtherThanHealthcare = 5700;
elseif strcmp(ScenarioName,'Stay in Maryland Bunker, Ruth Passes at 100');
    EVENTS.STATE_TAX.Table = [...
        2016 1 9 9
        3000 1 9 9];  % Third column is normal aggregate rate, fouth is retirement aggregate rate

    EVENTS.CASH_ADDITION.Table = [...
        2017	6  0
        2026	2  400000
        3000    1  0
        ];

    EVENTS.CASH_EXPENSES.Table = [...
    2016    11  0
    2017     4  0
    2017     11 0
    2018     4  0
    2018     11 0
    2019     4  0
    2019     11 0
    2020     4  0
    2020     11 0
    3000     1  0
    ];

    EVENTS.ExpensesOtherThanHealthcare = 6800;

elseif strcmp(ScenarioName,'Bicoastal Life, Ruth passes at 100, Then Move to Washington');

    EVENTS.CASH_EXPENSES.Table = [...
    2016    11  62000
    3000     1   0
    ];

    EVENTS.CASH_ADDITION.Table = [...
    2026	2  400000
    2026	6  100000
    3000    1   0
    ];

    EVENTS.STATE_TAX.Table = [...
        2016 1 9 9
        2026 6 0 0];  % Third column is normal aggregate rate, fouth is retirement aggregate rate
    
    EVENTS.ExpensesOtherThanHealthcare = 7800;
else
    fprintf('Error: undefined scenario %s',ScenarioName)
    keyboard
end

for ii = 1:size(EVENTS.STATE_TAX.Table,1);
    elasped_time = -(EVENTS.STATE_TAX.Table(ii,1) - Year(:) + (EVENTS.STATE_TAX.Table(ii,2) - Month(:))/12);
    EVENTS.STATE_TAX.AggregateTaxRateStateNormal_Pct(elasped_time >= 0) = EVENTS.STATE_TAX.Table(ii,3);
    EVENTS.STATE_TAX.AggregateTaxRateStateRet_Pct(elasped_time >= 0) = EVENTS.STATE_TAX.Table(ii,3);
%     keyboard
end

pmax = length(Month);
EVENTS.CASH_EXPENSES.value(1:pmax) = 0;
for ii = 1:size(EVENTS.CASH_EXPENSES.Table,1);
    elasped_time = EVENTS.CASH_EXPENSES.Table(ii,1) - Year(:) + (EVENTS.CASH_EXPENSES.Table(ii,2) - Month(:))/12;
    EVENTS.CASH_EXPENSES.value(abs(elasped_time) <= 1.e-10) = EVENTS.CASH_EXPENSES.Table(ii,3);
end

EVENTS.CASH_ADDITION.value(1:pmax) = 0;
for ii = 1:size(EVENTS.CASH_ADDITION.Table,1);
    elasped_time = EVENTS.CASH_ADDITION.Table(ii,1) - Year(:) + (EVENTS.CASH_ADDITION.Table(ii,2) - Month(:))/12;
    EVENTS.CASH_ADDITION.value(abs(elasped_time) <= 1.e-10) = EVENTS.CASH_ADDITION.Table(ii,3);
end
% keyboard
end
%----------------------------------------------------------------------
function [SandP_InflationCorrectedReturnTable] = loadSandP

SandP_InflationCorrectedReturnTable = [...
1927	40.27
1928	49.30
1929	-9.99
1930	-17.44
1931	-38.47
1932	4.98
1933	55.60
1934	-9.38
1935	50.44
1936	30.66
1937	-34.00
1938	20.86
1939	2.98
1940	-9.56
1941	-17.30
1942	11.66
1943	20.05
1944	16.98
1945	36.29
1946	-25.55
1947	-5.77
1948	6.33
1949	18.42
1950	26.76
1951	16.13
1952	17.46
1953	-1.54
1954	57.16
1955	27.74
1956	3.30
1957	-11.85
1958	40.92
1959	9.69
1960	-2.07
1961	27.65
1962	-10.39
1963	21.05
1964	15.47
1965	10.33
1966	-13.36
1967	20.78
1968	6.03
1969	-13.96
1970	-1.87
1971	10.92
1972	15.23
1973	-21.83
1974	-34.97
1975	29.48
1976	18.44
1977	-13.57
1978	-2.39
1979	4.76
1980	17.99
1981	-13.08
1982	16.75
1983	18.63
1984	1.93
1985	27.40
1986	17.77
1987	1.20
1989	26.14
1990	-8.98
1991	27.06
1992	4.57
1993	7.22
1994	-1.45
1995	34.60
1996	19.10
1997	31.43
1998	26.69
1999	17.94
2000	-12.09
2001	-13.32
2002	-24.07
2003	26.35
2004	7.33
2005	1.33
2006	12.87
2007	1.34
2008	-37.28
2009	23.75
2010	13.14
2011	-0.87
2012	13.91
2013	30.50
2014	12.94];
end